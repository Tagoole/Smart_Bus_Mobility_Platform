importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// TODO: Replace the following with your app's Firebase project configuration
firebase.initializeApp({
  apiKey: "AIzaSyCubxwd8oHSNGm1NZ2cYKGbw9xECfwbo_U",
  authDomain: "smart-bus-mobility.firebaseapp.com",
  projectId: "smart-bus-mobility",
  storageBucket: "smart-bus-mobility.firebasestorage.app",
  messagingSenderId: "231972373008",
  appId: "1:231972373008:web:1a4083885857e628c48095"
});

const messaging = firebase.messaging(); 
