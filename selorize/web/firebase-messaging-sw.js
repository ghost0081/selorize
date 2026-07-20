importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCfe1aVOoofP1re1dMK-t2CXFUGAIF91HM",
  appId: "1:556379754584:web:c29c75cc1dd39300403a2d",
  messagingSenderId: "556379754584",
  projectId: "selorize",
  authDomain: "selorize.firebaseapp.com",
  storageBucket: "selorize.firebasestorage.app",
});

const messaging = firebase.messaging();
