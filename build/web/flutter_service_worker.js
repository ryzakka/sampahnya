'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "e445c89421e0319f299a3f7325e3b0e7",
"assets/AssetManifest.bin.json": "630f604dca787e688ebe69239e93f703",
"assets/assets/audio/beach1.mp3": "5ae7bc4955ba87266ba453cb77f72ae4",
"assets/assets/audio/beach2.mp3": "af2c5373ae7eb3f66f612fe7c991f27e",
"assets/assets/audio/friendly1.mp3": "2b13064e4feaf78bd38b40bba978c88d",
"assets/assets/audio/friendly2.mp3": "418ebb7fd787ed05fecd8d9914c42641",
"assets/assets/audio/friendly3.mp3": "d906eac2890bf871c072e8e269b98467",
"assets/assets/audio/friendly4.mp3": "8733d69a5c0697a80cf0c2cd99a9f577",
"assets/assets/icon/accept.png": "a7d7c8d69eaca56cdcda202d6c3df729",
"assets/assets/icon/addbin.png": "205a6ae569226d2fdd064f4feada21e8",
"assets/assets/icon/addfence.png": "c4d05271719d99db01fb39bda6d05285",
"assets/assets/icon/addpet.png": "1ee79367ab95238ccfce40849765b7ca",
"assets/assets/icon/addroom.png": "dc6d7a2122f6734b561b671116d91cfd",
"assets/assets/icon/agree.png": "559cfed933ae577866bbbd8393e60564",
"assets/assets/icon/bin.png": "35a6b5082e593084082a3adbae9572df",
"assets/assets/icon/binbig.png": "ba0678b04a2f4f0b3f50914c23abdcae",
"assets/assets/icon/calltruck.png": "d18a209537686ff389e26b7aeac91824",
"assets/assets/icon/cancel.png": "249d0082c17890f8e25f7ad539ea4aa1",
"assets/assets/icon/coinbunk.png": "e928ad6a59ffc08d13d7cf8176ab528c",
"assets/assets/icon/construct.png": "59546938531c9c8523e607922c2db9a7",
"assets/assets/icon/defence.png": "41a40efa2327f11e2729912178a252d8",
"assets/assets/icon/disaster.png": "56406c8379114c938f2910763bf0701d",
"assets/assets/icon/emoji.png": "c104fbf03cc4c60d028eeab18580813a",
"assets/assets/icon/ikon.png": "5ee805e72aa2fa0dd552b0c7e236de0c",
"assets/assets/icon/list.png": "94e9d9eed93ec60916b796ccdbbedbd1",
"assets/assets/icon/load.png": "3c34cd75f83d9335cb9e7d18208247bc",
"assets/assets/icon/logo.png": "864cf7e6049a215db126b366ef2301d4",
"assets/assets/icon/polutan.png": "52ea002ead55b4ae42ec6662f469e210",
"assets/assets/icon/start.png": "d6d403148eb0d63e686012db633c6d0a",
"assets/assets/icon/timer.png": "4642bccef014ea9bae4fc61f4a8db6ae",
"assets/assets/icon/truckload.png": "dfdf92ac694fb6258daabfddb3ea3d78",
"assets/assets/icon/uphouse.png": "176ffd2132f35e1cbf743f5b64691494",
"assets/assets/icon/virus.png": "d0d0b19182a75010c5dd8aae70d0b729",
"assets/assets/icon/warning.png": "aa768d9554878be4578f5b5c73348d2a",
"assets/assets/icon/werehouse.png": "f19d47af166586223003b418b48ce888",
"assets/assets/soundeffect/beep-warning.mp3": "0f496cccf18e59028d278c2dd8fb29bd",
"assets/assets/soundeffect/building-collapse.mp3": "5022e8c2ffa757db8926bba8ca99167c",
"assets/assets/soundeffect/collapse.mp3": "a1ae5632468e2e59d0b07325e4325c23",
"assets/assets/soundeffect/confirm.mp3": "c345abcce4038827eed7215ac2e1e8a6",
"assets/assets/soundeffect/construct-crane.mp3": "ed64159631967ddf42b915bc074d448e",
"assets/assets/soundeffect/construct-hammer.mp3": "cfd5377f4f18a8cd92dbc33698d172bb",
"assets/assets/soundeffect/door.mp3": "21e64bc305eae8fa056f72acf178462f",
"assets/assets/soundeffect/fireburn.mp3": "9c0c6799b7da47784ae75bc95ce93bc1",
"assets/assets/soundeffect/fly1.mp3": "8f1e2573bd289590eaf75ad9fd1e9a8f",
"assets/assets/soundeffect/fly2.mp3": "19db3f4ec1bed8f79941b145693a46f5",
"assets/assets/soundeffect/game-lose.mp3": "97a00e0544821eafe2bd0673e0cf03de",
"assets/assets/soundeffect/game-win.mp3": "3d209803f35fcc624167f9a634d6f5eb",
"assets/assets/soundeffect/opening-singleplayer.mp3": "169746367233aef95ed65bcd7f3fe1e2",
"assets/assets/soundeffect/opening.mp3": "426fbdaa6f79e62cf8bfba05534aec34",
"assets/assets/soundeffect/police.mp3": "57e07ccc3be2b70c827d6a5be9025e37",
"assets/assets/soundeffect/rain.mp3": "c64852b8311545e7a2b790c5e19663dc",
"assets/assets/soundeffect/truck-beep.mp3": "48736f14c3a31d0ab33d749b945e0131",
"assets/assets/soundeffect/truck-moving.mp3": "e499c6368c7696a565b5d9beec661db5",
"assets/assets/soundeffect/upgrade.mp3": "083e0cd8435e374e6c2d0fb825c2d3b5",
"assets/assets/soundeffect/werehouse-open.mp3": "ed02007c2a536117163cf399689dfc98",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "51d3e1a9f7ae7a13a5a58852336d3219",
"assets/NOTICES": "16a1f2326957ee9123baf2296b261684",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"favicon.png": "cef9945067c8e42e22ce854272d61ca7",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "ddc4f353251f9a6412eb521d9bc1df6b",
"icons/Icon-192.png": "10fdcb59872d56c2f23bf5ce0f3647e4",
"icons/Icon-512.png": "ca04c82c18140ba47e642f4073fe916c",
"icons/Icon-maskable-192.png": "10fdcb59872d56c2f23bf5ce0f3647e4",
"icons/Icon-maskable-512.png": "ca04c82c18140ba47e642f4073fe916c",
"index.html": "cc4e10eefc1c6dc0b52c2fef8de73ba0",
"/": "cc4e10eefc1c6dc0b52c2fef8de73ba0",
"main.dart.js": "1f18a6706bb38add08cc86811aee46e3",
"manifest.json": "d316d9ed99bda221a3552b255fc6882b",
"vercel.json": "12493a52135ce2c149db40c740fb0c03",
"version.json": "05a7c32c8c504f08296b220fd7485482"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
