import assert from 'node:assert/strict';

const projectId = 'prm393-final';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const authBase = `http://${authHost}/identitytoolkit.googleapis.com/v1`;
const firestoreBase = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents`;
const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const results = [];

function record(name, expected, actual, passed) {
  results.push({ name, expected, actual, passed });
  process.stdout.write(`${passed ? 'PASS' : 'FAIL'} | ${name} | expected: ${expected} | actual: ${actual}\n`);
}

async function postJson(url, body, token) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let data = {};
  try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
  return { status: response.status, data };
}

async function getJson(url, token) {
  const response = await fetch(url, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
  const text = await response.text();
  let data = {};
  try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
  return { status: response.status, data };
}

function value(value) {
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return { integerValue: String(value) };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  throw new TypeError(`Unsupported Firestore test value: ${value}`);
}

function firestoreDocument(path, fields) {
  return {
    update: {
      name: `projects/${projectId}/databases/(default)/documents/${path}`,
      fields: Object.fromEntries(Object.entries(fields).map(([key, item]) => [key, value(item)])),
    },
  };
}

function claimId(name) {
  return name.trim().toLowerCase().replaceAll('%', '%25').replaceAll('/', '%2F');
}

function recipeData({ id, uid, name, overrides = {} }) {
  return {
    id,
    userId: uid,
    name,
    category: 'Dinner',
    difficulty: 'Easy',
    cookTime: 25,
    favorite: false,
    notes: '',
    createdAt: new Date(),
    ...overrides,
  };
}

function claimData({ uid, id, name }) {
  return { userId: uid, normalizedName: name.trim().toLowerCase(), recipeId: id };
}

async function createAccount(email, password) {
  const result = await postJson(`${authBase}/accounts:signUp?key=fake-api-key`, {
    email,
    password,
    returnSecureToken: true,
  });
  return result;
}

async function signIn(email, password) {
  return postJson(`${authBase}/accounts:signInWithPassword?key=fake-api-key`, {
    email,
    password,
    returnSecureToken: true,
  });
}

async function createRecipe(token, uid, id, name, overrides = {}) {
  const recipe = recipeData({ id, uid, name, overrides });
  const claim = claimData({ uid, id, name });
  return postJson(`${firestoreBase}:commit`, {
    writes: [
      firestoreDocument(`recipes/${id}`, recipe),
      firestoreDocument(`users/${uid}/recipeNameClaims/${claimId(name)}`, claim),
    ],
  }, token);
}

try {
  const emailA = `phase10a-a-${suffix}@example.test`;
  const passwordA = `test-${suffix}-A!`;
  const signupA = await createAccount(emailA, passwordA);
  assert.equal(signupA.status, 200, JSON.stringify(signupA.data));
  record('Authentication: register new account', 'account created', `HTTP ${signupA.status}`, true);

  const duplicateSignup = await createAccount(emailA, passwordA);
  const duplicateRejected = duplicateSignup.status >= 400;
  record('Authentication: register existing email', 'request rejected', `HTTP ${duplicateSignup.status}`, duplicateRejected);
  assert(duplicateRejected, JSON.stringify(duplicateSignup.data));

  const validLogin = await signIn(emailA, passwordA);
  assert.equal(validLogin.status, 200, JSON.stringify(validLogin.data));
  const tokenA = validLogin.data.idToken;
  const uidA = validLogin.data.localId;
  record('Authentication: valid credentials', 'signed in with account A', `HTTP ${validLogin.status}`, true);

  const invalidLogin = await signIn(emailA, `wrong-${passwordA}`);
  const invalidLoginRejected = invalidLogin.status >= 400;
  record('Authentication: invalid credentials', 'request rejected', `HTTP ${invalidLogin.status}`, invalidLoginRejected);
  assert(invalidLoginRejected, JSON.stringify(invalidLogin.data));

  const emailB = `phase10a-b-${suffix}@example.test`;
  const passwordB = `test-${suffix}-B!`;
  const signupB = await createAccount(emailB, passwordB);
  assert.equal(signupB.status, 200, JSON.stringify(signupB.data));
  const tokenB = signupB.data.idToken;
  const uidB = signupB.data.localId;
  record('Authentication: create isolation account B', 'account created', `HTTP ${signupB.status}`, true);

  const recipeIdA = `phase10a-${suffix}-a`;
  const recipeName = `Phase 10A Soup ${suffix}`;
  const addA = await createRecipe(tokenA, uidA, recipeIdA, recipeName);
  assert.equal(addA.status, 200, JSON.stringify(addA.data));
  record('Recipe: add valid recipe for account A', 'recipe and unique-name claim saved', `HTTP ${addA.status}`, true);

  const getA = await getJson(`${firestoreBase}/recipes/${recipeIdA}`, tokenA);
  assert.equal(getA.status, 200, JSON.stringify(getA.data));
  record('Recipe: owner can read own recipe', 'recipe returned', `HTTP ${getA.status}`, true);

  const getB = await getJson(`${firestoreBase}/recipes/${recipeIdA}`, tokenB);
  const hiddenFromB = getB.status >= 400;
  record('Isolation: account B cannot read account A recipe', 'permission denied / not found', `HTTP ${getB.status}`, hiddenFromB);
  assert(hiddenFromB, JSON.stringify(getB.data));

  const listARecipesAsB = await postJson(`${firestoreBase}:runQuery`, {
    structuredQuery: {
      from: [{ collectionId: 'recipes' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'userId' },
          op: 'EQUAL',
          value: { stringValue: uidA },
        },
      },
    },
  }, tokenB);
  const listDenied = listARecipesAsB.status >= 400;
  record('Isolation: account B cannot query account A recipes', 'query denied', `HTTP ${listARecipesAsB.status}`, listDenied);
  assert(listDenied, JSON.stringify(listARecipesAsB.data));

  const duplicateId = `phase10a-${suffix}-duplicate`;
  const duplicateDirect = await postJson(`${firestoreBase}:commit`, {
    writes: [firestoreDocument(`recipes/${duplicateId}`, recipeData({
      id: duplicateId,
      uid: uidA,
      name: recipeName.toLowerCase(),
    }))],
  }, tokenA);
  const duplicateDenied = duplicateDirect.status >= 400;
  record('Recipe: direct case-insensitive duplicate write', 'Firestore rules reject write', `HTTP ${duplicateDirect.status}`, duplicateDenied);
  assert(duplicateDenied, JSON.stringify(duplicateDirect.data));

  const sameNameBId = `phase10a-${suffix}-b`;
  const sameNameB = await createRecipe(tokenB, uidB, sameNameBId, recipeName);
  assert.equal(sameNameB.status, 200, JSON.stringify(sameNameB.data));
  record('Isolation: different users may use same recipe name', 'account B write allowed', `HTTP ${sameNameB.status}`, true);

  const invalidId = `phase10a-${suffix}-invalid`;
  const invalidRecipe = await createRecipe(tokenA, uidA, invalidId, `Invalid ${suffix}`, { cookTime: 601 });
  const invalidRejected = invalidRecipe.status >= 400;
  record('Rules: invalid cookTime direct write', 'Firestore rules reject write', `HTTP ${invalidRecipe.status}`, invalidRejected);
  assert(invalidRejected, JSON.stringify(invalidRecipe.data));

  const invalidCases = [
    ['wrong userId', { userId: uidB }],
    ['invalid category', { category: 'Brunch' }],
    ['invalid difficulty', { difficulty: 'Expert' }],
    ['cookTime below range', { cookTime: 0 }],
    ['cookTime wrong type', { cookTime: '25' }],
    ['servings below range', { servings: 0 }],
    ['servings above range', { servings: 21 }],
    ['servings wrong type', { servings: '2' }],
    ['notes over 300 characters', { notes: 'n'.repeat(301) }],
    ['notes wrong type', { notes: 7 }],
    ['favorite wrong type', { favorite: 'false' }],
    ['createdAt wrong type', { createdAt: 'not-a-timestamp' }],
    ['extra field', { extraField: true }],
    ['name over 80 characters', { name: 'n'.repeat(81) }],
  ];
  for (const [label, overrides] of invalidCases) {
    const id = `phase10a-${suffix}-invalid-${results.length}`;
    const name = overrides.name ?? `Invalid ${label} ${suffix}`;
    const data = recipeData({ id, uid: uidA, name, overrides });
    const writes = [firestoreDocument(`recipes/${id}`, data)];
    if (name.trim().length > 0) {
      writes.push(firestoreDocument(
        `users/${uidA}/recipeNameClaims/${claimId(name)}`,
        claimData({ uid: uidA, id, name }),
      ));
    }
    const response = await postJson(`${firestoreBase}:commit`, { writes }, tokenA);
    const rejected = response.status >= 400;
    record(`Rules: reject ${label}`, 'Firestore rules reject write', `HTTP ${response.status}`, rejected);
    assert(rejected, JSON.stringify(response.data));
  }

  for (const [label, name] of [
    ['empty name', ''],
    ['spaces-only name', '   '],
  ]) {
    const id = `phase10a-${suffix}-invalid-name-${results.length}`;
    const response = await postJson(`${firestoreBase}:commit`, {
      writes: [firestoreDocument(`recipes/${id}`, recipeData({ id, uid: uidA, name }))],
    }, tokenA);
    const rejected = response.status >= 400;
    record(`Rules: reject ${label}`, 'Firestore rules reject write', `HTTP ${response.status}`, rejected);
    assert(rejected, JSON.stringify(response.data));
  }

  {
    const id = `phase10a-${suffix}-missing-field`;
    const data = recipeData({ id, uid: uidA, name: `Missing field ${suffix}` });
    delete data.difficulty;
    const response = await postJson(`${firestoreBase}:commit`, {
      writes: [
        firestoreDocument(`recipes/${id}`, data),
        firestoreDocument(
          `users/${uidA}/recipeNameClaims/${claimId(data.name)}`,
          claimData({ uid: uidA, id, name: data.name }),
        ),
      ],
    }, tokenA);
    const rejected = response.status >= 400;
    record('Rules: reject missing required field', 'Firestore rules reject write', `HTTP ${response.status}`, rejected);
    assert(rejected, JSON.stringify(response.data));
  }

  const update = await postJson(`${firestoreBase}:commit`, {
    writes: [{
      update: {
        name: `projects/${projectId}/databases/(default)/documents/recipes/${recipeIdA}`,
        fields: { cookTime: value(35), favorite: value(true) },
      },
      updateMask: { fieldPaths: ['cookTime', 'favorite'] },
    }],
  }, tokenA);
  assert.equal(update.status, 200, JSON.stringify(update.data));
  record('Recipe: edit cooking time and toggle favorite', 'owner update allowed', `HTTP ${update.status}`, true);

  const updated = await getJson(`${firestoreBase}/recipes/${recipeIdA}`, tokenA);
  assert.equal(updated.data.fields.cookTime.integerValue, '35');
  assert.equal(updated.data.fields.favorite.booleanValue, true);
  record('Persistence: edited values readable after server write', 'cookTime 35 and favorite true', 'values confirmed by Firestore emulator', true);

  const removeA = await postJson(`${firestoreBase}:commit`, {
    writes: [
      { delete: `projects/${projectId}/databases/(default)/documents/recipes/${recipeIdA}` },
      { delete: `projects/${projectId}/databases/(default)/documents/users/${uidA}/recipeNameClaims/${claimId(recipeName)}` },
    ],
  }, tokenA);
  assert.equal(removeA.status, 200, JSON.stringify(removeA.data));
  const deletedA = await getJson(`${firestoreBase}/recipes/${recipeIdA}`, tokenA);
  assert(deletedA.status >= 400, JSON.stringify(deletedA.data));
  record('Recipe: delete recipe and verify it is gone', 'delete succeeds and subsequent read is denied/not found', `delete HTTP ${removeA.status}; read HTTP ${deletedA.status}`, true);

  const removeB = await postJson(`${firestoreBase}:commit`, {
    writes: [
      { delete: `projects/${projectId}/databases/(default)/documents/recipes/${sameNameBId}` },
      { delete: `projects/${projectId}/databases/(default)/documents/users/${uidB}/recipeNameClaims/${claimId(recipeName)}` },
    ],
  }, tokenB);
  assert.equal(removeB.status, 200, JSON.stringify(removeB.data));
  record('Cleanup: remove emulator test recipe for account B', 'test document removed', `HTTP ${removeB.status}`, true);
} catch (error) {
  record('Firebase emulator smoke test', 'all scripted checks pass', String(error), false);
  process.exitCode = 1;
} finally {
  process.stdout.write(`\n${results.filter((item) => item.passed).length}/${results.length} checks passed.\n`);
}
