importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyCw_2gpp5q9iunnkrEA1vrC7v3Cg6xfq5w",
  appId: "1:848695406274:web:3298d2824f43edf2f0d55b",
  messagingSenderId: "848695406274",
  projectId: "feelscore-df565",
  authDomain: "feelscore-df565.firebaseapp.com",
  storageBucket: "feelscore-df565.firebasestorage.app",
  measurementId: "G-Y4XMLMTX48"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
