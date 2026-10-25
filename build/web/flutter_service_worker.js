'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "d0a8275d6477e6e38886a68b730e0f80",
"assets/AssetManifest.bin.json": "0d7e84fe8388ddede1be0eb2633f9f0c",
"assets/assets/audio/beach1.mp3": "5ae7bc4955ba87266ba453cb77f72ae4",
"assets/assets/audio/beach2.mp3": "af2c5373ae7eb3f66f612fe7c991f27e",
"assets/assets/audio/friendly1.mp3": "2b13064e4feaf78bd38b40bba978c88d",
"assets/assets/audio/friendly2.mp3": "418ebb7fd787ed05fecd8d9914c42641",
"assets/assets/audio/friendly3.mp3": "d906eac2890bf871c072e8e269b98467",
"assets/assets/audio/friendly4.mp3": "8733d69a5c0697a80cf0c2cd99a9f577",
"assets/assets/icon/accept.png": "a7d7c8d69eaca56cdcda202d6c3df729",
"assets/assets/icon/addbin.png": "205a6ae569226d2fdd064f4feada21e8",
"assets/assets/icon/addfence.png": "c4d05271719d99db01fb39bda6d05285",
"assets/assets/icon/addhouse.png": "ee7d94d239bbd5c0004baa29757391e5",
"assets/assets/icon/addinvite.png": "e2ee0134f56f09b8a2661397508c4a1a",
"assets/assets/icon/addpet.png": "1ee79367ab95238ccfce40849765b7ca",
"assets/assets/icon/addroom.png": "dc6d7a2122f6734b561b671116d91cfd",
"assets/assets/icon/agree.png": "559cfed933ae577866bbbd8393e60564",
"assets/assets/icon/alert.png": "7641a418c3943a86eb75303f4454cbfb",
"assets/assets/icon/alreadyorsip.png": "d732372d49259ea59e5b43201f85e38b",
"assets/assets/icon/appinfo.png": "56ef07e90f1621cd6f2f78389793eefd",
"assets/assets/icon/back.png": "493c6814f648215a90b9c67bfdd3de7d",
"assets/assets/icon/bin.png": "35a6b5082e593084082a3adbae9572df",
"assets/assets/icon/binbig.png": "ba0678b04a2f4f0b3f50914c23abdcae",
"assets/assets/icon/calltruck.png": "d18a209537686ff389e26b7aeac91824",
"assets/assets/icon/cancel.png": "249d0082c17890f8e25f7ad539ea4aa1",
"assets/assets/icon/character.png": "9ba95959cce1efbffcb893071182f683",
"assets/assets/icon/coinbunk.png": "e928ad6a59ffc08d13d7cf8176ab528c",
"assets/assets/icon/construct.png": "59546938531c9c8523e607922c2db9a7",
"assets/assets/icon/copy.png": "6560d09772cb0c3542d89b77d2f81046",
"assets/assets/icon/crown.png": "dc0783c99db8f75534cd9b1bb7ccfdc5",
"assets/assets/icon/crown2.png": "cc6f4984783d09d4cf165a921373e75d",
"assets/assets/icon/customization.png": "8d9fa168d39176cf725496081078f22e",
"assets/assets/icon/defence.png": "41a40efa2327f11e2729912178a252d8",
"assets/assets/icon/disaster.png": "56406c8379114c938f2910763bf0701d",
"assets/assets/icon/emoji.png": "c104fbf03cc4c60d028eeab18580813a",
"assets/assets/icon/gamemode.png": "f1284c32f268765039ec1d67acc89d8a",
"assets/assets/icon/grafikhigh.png": "ba0bebb7d86f82e2960de9b40b0da1be",
"assets/assets/icon/grafiklow.png": "c918bc62e967d1e07c4b7c14a4c3c8aa",
"assets/assets/icon/grafikmedium.png": "cef18fbc9ebb07e1579d0ad03e41f94c",
"assets/assets/icon/home.png": "aa7d20a763df851a8ee5c6e8b22f9fb5",
"assets/assets/icon/houseneighbor.png": "afa877d4462028799a2768b4569c6e15",
"assets/assets/icon/houseown.png": "e05ffe52f407e49ef4de863f73be517f",
"assets/assets/icon/howto.png": "1a22289c24db59e39a2281939eb12151",
"assets/assets/icon/ikon.png": "5ee805e72aa2fa0dd552b0c7e236de0c",
"assets/assets/icon/info.png": "3878349e1e634cafab076c1803bde8aa",
"assets/assets/icon/inseneratorecoplus.png": "6dd7be2bfb8c959cc17bf018ccf23d00",
"assets/assets/icon/inseneratorplus.png": "1d773dfc2c2f1a5efdd18bb986f40798",
"assets/assets/icon/joinroom.png": "4595e323da3e9fee6ef2ef179c03d829",
"assets/assets/icon/leaderboard.png": "ac20e8ccc890d7c9e12556d260e89b02",
"assets/assets/icon/left.png": "0127ff0a68763948516abf445bbcd036",
"assets/assets/icon/list.png": "94e9d9eed93ec60916b796ccdbbedbd1",
"assets/assets/icon/load.png": "3c34cd75f83d9335cb9e7d18208247bc",
"assets/assets/icon/logo.png": "864cf7e6049a215db126b366ef2301d4",
"assets/assets/icon/maps.png": "7f784e2e9c1a8a095b1dbdd68402c5ef",
"assets/assets/icon/movebintowerehouse.png": "c50a989aed43930308eab0d9d365a482",
"assets/assets/icon/name.png": "5b8106debb6c34792cdaaa49496856ec",
"assets/assets/icon/notyet.png": "9dbb6fcf152a4d86bd1e4cc886d2b1c7",
"assets/assets/icon/othergames.png": "9433eca862625dd3f58454cb30b5a422",
"assets/assets/icon/play.png": "4acdc9c8bcf896239b1e866fef895594",
"assets/assets/icon/player.png": "72b2ac85f41e75277c3a1e46568e6c8a",
"assets/assets/icon/poison.png": "7aa9e259a76e5a27bf6f8a0327dcf0ee",
"assets/assets/icon/polutan.png": "52ea002ead55b4ae42ec6662f469e210",
"assets/assets/icon/random.png": "22460b342fe7c75bdb10ee1eccde9b32",
"assets/assets/icon/right.png": "24f92e18800ee2c13def727699faa9a6",
"assets/assets/icon/roomcode.png": "d1d887ca4c752656c3613cbb4419a845",
"assets/assets/icon/sampah1.png": "8e9f586977c82393608fa98b32fde94d",
"assets/assets/icon/sampahbesar.png": "82180f550c437d4a183b5161213da2bd",
"assets/assets/icon/sampahkecil.png": "56c237a40374f77de00a94ef8b401e7e",
"assets/assets/icon/sampahplus.png": "d5c8820664c9039a42d475eea1c5fd5a",
"assets/assets/icon/setting.png": "d08e81ff8b0090f5535d2493666b57dd",
"assets/assets/icon/skip.png": "ea807095e1ed22c51368e98b05876f62",
"assets/assets/icon/start.png": "d6d403148eb0d63e686012db633c6d0a",
"assets/assets/icon/survival.png": "0b9185ce754d269d21beea9c58c6e1bb",
"assets/assets/icon/timer.png": "4642bccef014ea9bae4fc61f4a8db6ae",
"assets/assets/icon/timewait.png": "2a8661906bda2d35fea46ba60f484914",
"assets/assets/icon/toga.png": "eb4b6a401d876aaf23506c17096d6be4",
"assets/assets/icon/truckload.png": "dfdf92ac694fb6258daabfddb3ea3d78",
"assets/assets/icon/truckwerehouse.png": "0a853f6ea8fe3c4e871b1b331c12be32",
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
"assets/fonts/MaterialIcons-Regular.otf": "cb546108909d38d14a2b2e01d119d05a",
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
"flutter_bootstrap.js": "0396e05e814a5958577a7b4e8c9afda4",
"icons/Icon-192.png": "10fdcb59872d56c2f23bf5ce0f3647e4",
"icons/Icon-512.png": "ca04c82c18140ba47e642f4073fe916c",
"icons/Icon-maskable-192.png": "10fdcb59872d56c2f23bf5ce0f3647e4",
"icons/Icon-maskable-512.png": "ca04c82c18140ba47e642f4073fe916c",
"index.html": "cc4e10eefc1c6dc0b52c2fef8de73ba0",
"/": "cc4e10eefc1c6dc0b52c2fef8de73ba0",
"main.dart.js": "168a7400b402c55d4305ffa7d20340d0",
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
