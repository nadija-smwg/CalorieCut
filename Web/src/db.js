const DATABASE = 'caloriecut';
let database;
function open() {
  if (!database) database = new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('diary');
    request.onsuccess = () => {
      request.result.onversionchange = () => { request.result.close(); database = null; };
      resolve(request.result);
    };
    request.onerror = () => { database = null; reject(new Error('Device storage is unavailable. Allow website storage, then try again.')); };
    request.onblocked = () => { database = null; reject(new Error('Close other CalorieCut tabs, then reload.')); };
  });
  return database;
}
export async function loadDiary() {
  const db = await open();
  return new Promise((resolve, reject) => {
    const request = db.transaction('diary').objectStore('diary').get('current');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(new Error('Your diary could not be read. Reload to try again.'));
  });
}
export async function saveDiary(data, expectedRevision = 0) {
  const db = await open();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction('diary', 'readwrite');
    const store = transaction.objectStore('diary');
    let conflict = false;
    const request = store.get('current');
    request.onsuccess = () => {
      if ((request.result?.webRevision || 0) !== expectedRevision) { conflict = true; transaction.abort(); return; }
      try {
        data.webRevision = expectedRevision + 1;
        store.put(data, 'current');
      } catch { transaction.abort(); }
    };
    transaction.oncomplete = resolve;
    transaction.onerror = transaction.onabort = () => reject(new Error(conflict ? 'Your diary changed in another tab. Reload this page before saving again.' : 'Could not save. Device storage may be full or unavailable. Your previous diary is unchanged.'));
  });
}
