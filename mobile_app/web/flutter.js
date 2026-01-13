// Flutter web bootstrap script
'use strict';
const flutter_bootstrap = function() {
  return {
    loadEntrypoint: function(options) {
      const {
        entrypointUrl = "main.dart.js",
        onEntrypointLoaded,
        serviceWorker
      } = (options || {});
      
      return new Promise((resolve, reject) => {
        const scriptTag = document.createElement("script");
        scriptTag.src = entrypointUrl;
        scriptTag.type = "application/javascript";
        
        scriptTag.addEventListener("load", function(event) {
          if (onEntrypointLoaded) {
            onEntrypointLoaded({
              initializeEngine: function() {
                return _flutter.loader.didCreateEngineInitializer;
              }
            });
          }
          resolve();
        });
        
        scriptTag.addEventListener("error", function(event) {
          reject(new Error("Failed to load Flutter entrypoint"));
        });
        
        document.body.append(scriptTag);
      });
    },
    didCreateEngineInitializer: Promise.resolve({
      initializeEngine: function() {
        return Promise.resolve({
          runApp: function() {
            console.log("Flutter app started");
          }
        });
      }
    })
  };
};

window._flutter = window._flutter || {};
window._flutter.loader = flutter_bootstrap();
