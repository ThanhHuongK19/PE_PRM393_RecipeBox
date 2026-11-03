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
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
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
  const emailA = `phase10b-a-${suffix}@example.test`;
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

  const emailB = `phase10b-b-${suffix}@example.test`;
  const passwordB = `test-${suffix}-B!`;
  const signupB = await createAccount(emailB, passwordB);
  assert.equal(signupB.status, 200, JSON.stringify(signupB.data));
  const tokenB = signupB.data.idToken;
  const uidB = signupB.data.localId;
  record('Authentication: create isolation account B', 'account created', `HTTP ${signupB.status}`, true);

  const recipeIdA = `phase10b-${suffix}-a`;
  const recipeName = `Phase 10A Soup ${suffix}`;
  const addA = await createRecipe(tokenA, uidA, recipeIdA, recipeName);
  assert.equal(addA.status, 200, JSON.stringify(addA.data));
  record('Authenticated owner: create own recipe', 'recipe and unique-name claim saved', `HTTP ${addA.status}`, true);

  const docA = `projects/${projectId}/databases/(default)/documents/recipes/${recipeIdA}`;
  const claimA = `projects/${projectId}/databases/(default)/documents/users/${uidA}/recipeNameClaims/${claimId(recipeName)}`;
  const unauthRead = await getJson(`${firestoreBase}/recipes/${recipeIdA}`);
  const unauthReadDenied = unauthRead.status >= 400;
  record('Unauthenticated: read recipe', 'denied', `HTTP ${unauthRead.status}`, unauthReadDenied);
  assert(unauthReadDenied, JSON.stringify(unauthRead.data));

  const unauthQuery = await postJson(`${firestoreBase}:runQuery`, {
    structuredQuery: { from: [{ collectionId: 'recipes' }] },
  });
  const unauthQueryDenied = unauthQuery.status >= 400;
  record('Unauthenticated: list recipes', 'denied', `HTTP ${unauthQuery.status}`, unauthQueryDenied);
  assert(unauthQueryDenied, JSON.stringify(unauthQuery.data));

  const unauthCreateId = `phase10b-unauth-${suffix}`;
  const unauthCreateName = `Unauth ${suffix}`;
  const unauthCreate = await postJson(`${firestoreBase}:commit`, { writes: [
    firestoreDocument(`recipes/${unauthCreateId}`, recipeData({ id: unauthCreateId, uid: uidA, name: unauthCreateName })),
    firestoreDocument(`users/${uidA}/recipeNameClaims/${claimId(unauthCreateName)}`, claimData({ uid: uidA, id: unauthCreateId, name: unauthCreateName })),
  ] });
  const unauthCreateDenied = unauthCreate.status >= 400;
  record('Unauthenticated: create recipe', 'denied', `HTTP ${unauthCreate.status}`, unauthCreateDenied);
  assert(unauthCreateDenied, JSON.stringify(unauthCreate.data));

  const unauthUpdate = await postJson(`${firestoreBase}:commit`, { writes: [{
    update: { name: docA, fields: { cookTime: value(31) } },
    updateMask: { fieldPaths: ['cookTime'] },
  }] });
  const unauthUpdateDenied = unauthUpdate.status >= 400;
  record('Unauthenticated: update recipe', 'denied', `HTTP ${unauthUpdate.status}`, unauthUpdateDenied);
  assert(unauthUpdateDenied, JSON.stringify(unauthUpdate.data));

  const unauthDelete = await postJson(`${firestoreBase}:commit`, { writes: [
    { delete: docA }, { delete: claimA },
  ] });
  const unauthDeleteDenied = unauthDelete.status >= 400;
  record('Unauthenticated: delete recipe', 'denied', `HTTP ${unauthDelete.status}`, unauthDeleteDenied);
  assert(unauthDeleteDenied, JSON.stringify(unauthDelete.data));

  const getA = await getJson(`${firestoreBase}/recipes/${recipeIdA}`, tokenA);
  assert.equal(getA.status, 200, JSON.stringify(getA.data));
  record('Authenticated owner: read own recipe', 'recipe returned', `HTTP ${getA.status}`, true);

  const getB = await getJson(`${firestoreBase}/recipes/${recipeIdA}`, tokenB);
  const hiddenFromB = getB.status >= 400;
  record('Isolation: account B cannot read account A recipe', 'permission denied / not found', `HTTP ${getB.status}`, hiddenFromB);
  assert(hiddenFromB, JSON.stringify(getB.data));

  const crossUpdate = await postJson(`${firestoreBase}:commit`, { writes: [{
    update: { name: docA, fields: { cookTime: value(32) } },
    updateMask: { fieldPaths: ['cookTime'] },
  }] }, tokenB);
  const crossUpdateDenied = crossUpdate.status >= 400;
  record('Isolation: account B cannot update account A recipe', 'denied', `HTTP ${crossUpdate.status}`, crossUpdateDenied);
  assert(crossUpdateDenied, JSON.stringify(crossUpdate.data));

  const crossDelete = await postJson(`${firestoreBase}:commit`, { writes: [
    { delete: docA }, { delete: claimA },
  ] }, tokenB);
  const crossDeleteDenied = crossDelete.status >= 400;
  record('Isolation: account B cannot delete account A recipe', 'denied', `HTTP ${crossDelete.status}`, crossDeleteDenied);
  assert(crossDeleteDenied, JSON.stringify(crossDelete.data));

  const afterCrossAttempts = await getJson(`${firestoreBase}/recipes/${recipeIdA}`, tokenA);
  assert.equal(afterCrossAttempts.status, 200, JSON.stringify(afterCrossAttempts.data));
  record("Isolation: cross-user attempts preserve owner's recipe", 'recipe remains readable by owner', `HTTP ${afterCrossAttempts.status}`, true);

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

  const duplicateId = `phase10b-${suffix}-duplicate`;
  const duplicateName = recipeName.toLowerCase();
  const duplicateDirect = await postJson(`${firestoreBase}:commit`, { writes: [
    firestoreDocument(`recipes/${duplicateId}`, recipeData({
      id: duplicateId, uid: uidA, name: duplicateName,
    })),
    firestoreDocument(`users/${uidA}/recipeNameClaims/${claimId(duplicateName)}`, claimData({
      uid: uidA, id: duplicateId, name: duplicateName,
    })),
  ] }, tokenA);
  const duplicateDenied = duplicateDirect.status >= 400;
  record('Recipe: direct case-insensitive duplicate write', 'Firestore rules reject write', `HTTP ${duplicateDirect.status}`, duplicateDenied);
  assert(duplicateDenied, JSON.stringify(duplicateDirect.data));

  const sameNameBId = `phase10b-${suffix}-b`;
  const sameNameB = await createRecipe(tokenB, uidB, sameNameBId, recipeName);
  assert.equal(sameNameB.status, 200, JSON.stringify(sameNameB.data));
  record('Isolation: different users may use same recipe name', 'account B write allowed', `HTTP ${sameNameB.status}`, true);

  const invalidId = `phase10b-${suffix}-invalid`;
  const invalidRecipe = await createRecipe(tokenA, uidA, invalidId, `Invalid ${suffix}`, { cookTime: 601 });
  const invalidRejected = invalidRecipe.status >= 400;
  record('Rules: invalid cookTime direct write', 'Firestore rules reject write', `HTTP ${invalidRecipe.status}`, invalidRejected);
  assert(invalidRejected, JSON.stringify(invalidRecipe.data));

  const invalidCases = [
    ['wrong userId', { userId: uidB }],
    ['invalid category', { category: 'Brunch' }],
    ['invalid difficulty', { difficulty: 'Expert' }],
    ['cookTime below range', { cookTime: 0 }],
    ['cookTime above range', { cookTime: 601 }],
    ['cookTime wrong type', { cookTime: '25' }],
    ['decimal cookTime', { cookTime: 25.5 }],
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
    const id = `phase10b-${suffix}-invalid-${results.length}`;
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

  {
    const id = `phase10b-${suffix}-missing-cook-time`;
    const name = `Missing cookTime ${suffix}`;
    const data = recipeData({ id, uid: uidA, name });
    delete data.cookTime;
    const response = await postJson(`${firestoreBase}:commit`, { writes: [
      firestoreDocument(`recipes/${id}`, data),
      firestoreDocument(`users/${uidA}/recipeNameClaims/${claimId(name)}`, claimData({ uid: uidA, id, name })),
    ] }, tokenA);
    const rejected = response.status >= 400;
    record('Rules: reject missing cookTime', 'Firestore rules reject write', `HTTP ${response.status}`, rejected);
    assert(rejected, JSON.stringify(response.data));
  }

  for (const field of ['id', 'userId', 'name', 'category', 'difficulty', 'cookTime', 'favorite', 'createdAt']) {
    const id = `phase10b-${suffix}-missing-${field}`;
    const name = `Missing ${field} ${suffix}`;
    const data = recipeData({ id, uid: uidA, name });
    delete data[field];
    const writes = [firestoreDocument(`recipes/${id}`, data)];
    if (field !== 'name') {
      writes.push(firestoreDocument(
        `users/${uidA}/recipeNameClaims/${claimId(name)}`,
        claimData({ uid: uidA, id, name }),
      ));
    }
    const response = await postJson(`${firestoreBase}:commit`, { writes }, tokenA);
    const rejected = response.status >= 400;
    record(`Rules: reject missing required ${field}`, 'Firestore rules reject write', `HTTP ${response.status}`, rejected);
    assert(rejected, JSON.stringify(response.data));
  }

  for (const [label, name] of [
    ['empty name', ''],
    ['spaces-only name', '   '],
  ]) {
    const id = `phase10b-${suffix}-invalid-name-${results.length}`;
    const response = await postJson(`${firestoreBase}:commit`, {
      writes: [firestoreDocument(`recipes/${id}`, recipeData({ id, uid: uidA, name }))],
    }, tokenA);
    const rejected = response.status >= 400;
    record(`Rules: reject ${label}`, 'Firestore rules reject write', `HTTP ${response.status}`, rejected);
    assert(rejected, JSON.stringify(response.data));
  }

  {
    const id = `phase10b-${suffix}-missing-field`;
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
  record('Phase 10B Firestore Rules verification', 'all scripted checks pass', String(error), false);
  process.exitCode = 1;
} finally {
  process.stdout.write(`\n${results.filter((item) => item.passed).length}/${results.length} checks passed.\n`);
}

