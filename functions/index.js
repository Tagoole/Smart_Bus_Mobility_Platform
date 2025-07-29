const functions = require("firebase-functions");
const express = require("express");
const axios = require("axios");
const {v4: uuidv4} = require("uuid");
const cors = require("cors");
const admin = require("firebase-admin");

// Initialize Firebase Admin
admin.initializeApp();

const app = express();

// Middleware
app.use(express.json());
app.use(cors());

// Authentication middleware
const authenticateRequest = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      // Allow requests without authentication for now
      return next();
    }

    const token = authHeader.split("Bearer ")[1];
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    // Allow requests without authentication for now
    next();
  }
};

app.use(authenticateRequest);

// MTN MoMo API Configuration
const MOMO_CONFIG = {
  baseURL: process.env.MOMO_BASE_URL || "https://sandbox.momodeveloper.mtn.com",
  subscriptionKey: "8df0f2fc72c84361978de2c50a7d0a3d",
  userId: "51a06b51-7b0e-45be-b321-ac37e90ea807",
  apiKey: "7e4cc124b84441c4a3535a0cf756ab7d",
  targetEnvironment: process.env.MOMO_TARGET_ENVIRONMENT || "sandbox",
};

// Store for access tokens (in production, use Redis or database)
const accessTokens = {
  collection: null,
  disbursement: null,
  remittance: null,
};

// Utility function to generate basic auth
const generateBasicAuth = (userId, apiKey) => {
  return Buffer.from(`${userId}:${apiKey}`).toString("base64");
};

// Get Access Token for Collection API
const getCollectionAccessToken = async () => {
  try {
    const response = await axios.post(
        `${MOMO_CONFIG.baseURL}/collection/token/`,
        {},
        {
          headers: {
            "Authorization": `Basic ${generateBasicAuth(
                MOMO_CONFIG.userId,
                MOMO_CONFIG.apiKey)}`,
            "Ocp-Apim-Subscription-Key": MOMO_CONFIG.subscriptionKey,
            "X-Target-Environment": MOMO_CONFIG.targetEnvironment,
          },
        },
    );

    accessTokens.collection = {
      token: response.data.access_token,
      expiresAt: Date.now() + (response.data.expires_in * 1000),
    };

    return response.data.access_token;
  } catch (error) {
    console.error("Error getting collection access token:",
        (error.response && error.response.data) || error.message);
    throw error;
  }
};

// Get valid access token (refresh if expired)
const getValidAccessToken = async (type = "collection") => {
  const tokenData = accessTokens[type];

  if (!tokenData || Date.now() >= tokenData.expiresAt) {
    switch (type) {
      case "collection":
        return await getCollectionAccessToken();
      default:
        return await getCollectionAccessToken();
    }
  }

  return tokenData.token;
};

// Routes

// Health check
app.get("/health", (req, res) => {
  console.log("Health check endpoint called");
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
    message: "Backend is running",
  });
});

// Test endpoint
app.get("/test", (req, res) => {
  console.log("Test endpoint called");
  res.json({
    message: "Test endpoint working",
    config: {
      baseURL: MOMO_CONFIG.baseURL,
      targetEnvironment: MOMO_CONFIG.targetEnvironment,
      hasSubscriptionKey: !!MOMO_CONFIG.subscriptionKey,
      hasUserId: !!MOMO_CONFIG.userId,
      hasApiKey: !!MOMO_CONFIG.apiKey,
    },
  });
});

// Request to Pay
app.post("/api/requesttopay", async (req, res) => {
  try {
    const {amount, currency, externalId, payer, payerMessage, payeeNote} =
      req.body;

    // Validation
    if (!amount || !currency || !externalId ||
      !(payer && payer.partyId)) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields: amount, currency, " +
          "externalId, payer.partyId",
      });
    }

    const accessToken = await getValidAccessToken("collection");
    const referenceId = uuidv4();

    const requestData = {
      amount: amount.toString(),
      currency: currency || "EUR",
      externalId: externalId,
      payer: {
        partyIdType: payer.partyIdType || "MSISDN",
        partyId: payer.partyId,
      },
      payerMessage: payerMessage || "Payment request",
      payeeNote: payeeNote || "Payment from mobile app",
    };

    const response = await axios.post(
        `${MOMO_CONFIG.baseURL}/collection/v1_0/requesttopay`,
        requestData,
        {
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Reference-Id": referenceId,
            "X-Target-Environment": MOMO_CONFIG.targetEnvironment,
            "Ocp-Apim-Subscription-Key": MOMO_CONFIG.subscriptionKey,
            "Content-Type": "application/json",
          },
        },
    );

    res.json({
      success: true,
      referenceId: referenceId,
      message: "Payment request initiated successfully",
      data: response.data,
    });
  } catch (error) {
    console.error("RequestToPay Error:",
        (error.response && error.response.data) || error.message);
    res.status(500).json({
      success: false,
      message: "Failed to initiate payment request",
      error: (error.response && error.response.data) || error.message,
    });
  }
});

// Get Transaction Status
app.get("/api/transaction/:referenceId", async (req, res) => {
  try {
    const {referenceId} = req.params;

    if (!referenceId) {
      return res.status(400).json({
        success: false,
        message: "Reference ID is required",
      });
    }

    const accessToken = await getValidAccessToken("collection");

    const response = await axios.get(
        `${MOMO_CONFIG.baseURL}/collection/v1_0/requesttopay/${referenceId}`,
        {
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Target-Environment": MOMO_CONFIG.targetEnvironment,
            "Ocp-Apim-Subscription-Key": MOMO_CONFIG.subscriptionKey,
          },
        },
    );

    res.json({
      success: true,
      data: response.data,
    });
  } catch (error) {
    console.error("Get Transaction Error:",
        (error.response && error.response.data) || error.message);
    res.status(500).json({
      success: false,
      message: "Failed to get transaction status",
      error: (error.response && error.response.data) || error.message,
    });
  }
});

// Get Account Balance
app.get("/api/balance", async (req, res) => {
  try {
    const accessToken = await getValidAccessToken("collection");

    const response = await axios.get(
        `${MOMO_CONFIG.baseURL}/collection/v1_0/account/balance`,
        {
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Target-Environment": MOMO_CONFIG.targetEnvironment,
            "Ocp-Apim-Subscription-Key": MOMO_CONFIG.subscriptionKey,
          },
        },
    );

    res.json({
      success: true,
      data: response.data,
    });
  } catch (error) {
    console.error("Get Balance Error:",
        (error.response && error.response.data) || error.message);
    res.status(500).json({
      success: false,
      message: "Failed to get account balance",
      error: (error.response && error.response.data) || error.message,
    });
  }
});

// Get Account Holder Info
app.post("/api/accountholder", async (req, res) => {
  try {
    const {accountHolderIdType, accountHolderId} = req.body;

    if (!accountHolderIdType || !accountHolderId) {
      return res.status(400).json({
        success: false,
        message: "accountHolderIdType and accountHolderId are required",
      });
    }

    const accessToken = await getValidAccessToken("collection");

    const response = await axios.get(
        `${MOMO_CONFIG.baseURL}/collection/v1_0/accountholder/` +
        `${accountHolderIdType}/${accountHolderId}/basicuserinfo`,
        {
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Target-Environment": MOMO_CONFIG.targetEnvironment,
            "Ocp-Apim-Subscription-Key": MOMO_CONFIG.subscriptionKey,
          },
        },
    );

    res.json({
      success: true,
      data: response.data,
    });
  } catch (error) {
    console.error("Get Account Holder Error:",
        (error.response && error.response.data) || error.message);
    res.status(500).json({
      success: false,
      message: "Failed to get account holder info",
      error: (error.response && error.response.data) || error.message,
    });
  }
});

// Validate Account Holder
app.post("/api/validate-account", async (req, res) => {
  try {
    const {accountHolderIdType, accountHolderId} = req.body;

    if (!accountHolderIdType || !accountHolderId) {
      return res.status(400).json({
        success: false,
        message: "accountHolderIdType and accountHolderId are required",
      });
    }

    const accessToken = await getValidAccessToken("collection");

    const response = await axios.get(
        `${MOMO_CONFIG.baseURL}/collection/v1_0/accountholder/` +
        `${accountHolderIdType}/${accountHolderId}/active`,
        {
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Target-Environment": MOMO_CONFIG.targetEnvironment,
            "Ocp-Apim-Subscription-Key": MOMO_CONFIG.subscriptionKey,
          },
        },
    );

    res.json({
      success: true,
      isActive: response.status === 200,
      data: response.data,
    });
  } catch (error) {
    if (error.response && error.response.status === 404) {
      res.json({
        success: true,
        isActive: false,
        message: "Account holder not found or inactive",
      });
    } else {
      console.error("Validate Account Error:",
          (error.response && error.response.data) || error.message);
      res.status(500).json({
        success: false,
        message: "Failed to validate account holder",
        error: (error.response && error.response.data) || error.message,
      });
    }
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error("Unhandled error:", error);
  res.status(500).json({
    success: false,
    message: "Internal server error",
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Endpoint not found",
  });
});

// Export as 1st Gen Firebase Function (public by default)
exports.api = functions.https.onRequest(app);


