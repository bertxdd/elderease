<?php

declare(strict_types=1);

// Update these values with your Hostinger DB credentials.
const DB_HOST = 'localhost';
const DB_NAME = 'u793073111_elderease';
const DB_USER = 'u793073111_elderease';
const DB_PASS = 'Elderease1';

// Set to false in production.
const APP_DEBUG = false;

// Auto-expire unaccepted requests after this many minutes.
const REQUEST_AUTO_EXPIRE_MINUTES = 30;

// EmailJS configuration (optional, used for volunteer approval notification emails).
const EMAILJS_SERVICE_ID = 'service_b5xzlx8';
const EMAILJS_TEMPLATE_ID = 'template_y8zwrkc';
const EMAILJS_PUBLIC_KEY = '99bTMB66BTfKoyA6z';
const EMAILJS_PRIVATE_KEY = 'wJd-Rofsa9VIVxLTG593u';
const EMAILJS_ENDPOINT = 'https://api.emailjs.com/api/v1.0/email/send';

// PhilSMS configuration (optional, used for volunteer approval SMS notifications).
const PHILSMS_API_URL = 'https://dashboard.philsms.com/api/v3/sms/send';
const PHILSMS_SENDER_ID = 'PhilSMS';
const PHILSMS_TOKEN = '2635|19hTVHGV2p0gf9tjJMYqvk1U0ccc4f3ndYNpblNl3890acf0';
