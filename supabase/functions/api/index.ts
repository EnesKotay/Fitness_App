import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import bcrypt from "bcryptjs";
import { createRemoteJWKSet, jwtVerify, SignJWT } from "jose";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
};

type UserRow = Record<string, unknown>;

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const googleJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);
const appleJwks = createRemoteJWKSet(
  new URL("https://appleid.apple.com/auth/keys"),
);

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const body = await req.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new Error("Invalid JSON body");
    }
    return body as Record<string, unknown>;
  } catch {
    throw new Error("Gecersiz istek govdesi");
  }
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function normalizeEmail(value: unknown): string {
  return asString(value).trim().toLowerCase();
}

function validateEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function parseCsv(value: string | null, fallback: string[] = []): string[] {
  if (!value || !value.trim()) return fallback;
  return value
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
}

function hasOwn(body: Record<string, unknown>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(body, key);
}

function optionalNumber(value: unknown, fieldName: string): number | null {
  if (value === null) return null;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  throw new Error(`${fieldName} gecersiz`);
}

function requiredNumber(value: unknown, fieldName: string): number {
  const parsed = optionalNumber(value, fieldName);
  if (parsed === null) {
    throw new Error(`${fieldName} gerekli`);
  }
  return parsed;
}

function requiredInteger(value: unknown, fieldName: string): number {
  const parsed = requiredNumber(value, fieldName);
  if (!Number.isInteger(parsed)) {
    throw new Error(`${fieldName} tam sayi olmali`);
  }
  return parsed;
}

function optionalInteger(value: unknown, fieldName: string): number | null {
  const parsed = optionalNumber(value, fieldName);
  if (parsed === null) return null;
  if (!Number.isInteger(parsed)) {
    throw new Error(`${fieldName} tam sayi olmali`);
  }
  return parsed;
}

function optionalTrimmedString(value: unknown): string | null {
  if (value === null) return null;
  return asString(value).trim();
}

function trimOrNull(value: unknown): string | null {
  const text = asString(value).trim();
  return text ? text : null;
}

function optionalRawString(value: unknown): string | null {
  if (value === null) return null;
  return asString(value);
}

function jsonArray(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (typeof value === "string" && value.trim()) {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

function toJsonText(value: unknown): string {
  return JSON.stringify(Array.isArray(value) ? value : []);
}

function appendGoalHistory(existing: unknown, goal: string): string {
  const entry = {
    goal,
    changedAt: new Date().toISOString(),
  };

  if (typeof existing === "string" && existing.trim().startsWith("[")) {
    try {
      const parsed = JSON.parse(existing);
      if (Array.isArray(parsed)) {
        parsed.push(entry);
        return JSON.stringify(parsed);
      }
    } catch {
      // Fall through to a fresh history array.
    }
  }

  return JSON.stringify([entry]);
}

function parsePositiveInt(value: string | null, fallback: number): number {
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

function isNumericPathSegment(value: string): boolean {
  return /^\d+$/.test(value);
}

function dayRange(date: string): { start: string; end: string } {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new Error("Gecersiz tarih");
  }
  const startDate = new Date(`${date}T00:00:00.000Z`);
  if (Number.isNaN(startDate.getTime())) {
    throw new Error("Gecersiz tarih");
  }
  const endDate = new Date(startDate.getTime() + 24 * 60 * 60 * 1000);
  return {
    start: date,
    end: endDate.toISOString().slice(0, 10),
  };
}

function addMonths(date: Date, months: number): Date {
  const next = new Date(date);
  next.setMonth(next.getMonth() + months);
  return next;
}

function jwtSecret(): Uint8Array {
  const secret = Deno.env.get("JWT_SECRET_KEY");
  if (!secret || !secret.trim()) {
    throw new Error("JWT_SECRET_KEY ortam degiskeni ayarlanmamis");
  }
  return new TextEncoder().encode(secret);
}

async function buildJwt(user: UserRow): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({
    email: normalizeEmail(user.email),
    name: asString(user.name),
  })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(String(user.id))
    .setIssuer("fitness-backend")
    .setIssuedAt(now)
    .setExpirationTime(now + 7 * 24 * 60 * 60)
    .sign(jwtSecret());
}

async function userIdFromAuthorization(req: Request): Promise<number> {
  const authorization = req.headers.get("authorization");
  if (!authorization) {
    throw new Error("Gecersiz veya eksik Authorization header");
  }

  const match = authorization.trim().match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new Error("Gecersiz veya eksik Authorization header");
  }

  const { payload } = await jwtVerify(match[1], jwtSecret(), {
    issuer: "fitness-backend",
    clockTolerance: 5,
  });

  const sub = payload.sub;
  if (!sub) {
    throw new Error("Token subject yok");
  }

  const userId = Number.parseInt(sub, 10);
  if (!Number.isFinite(userId)) {
    throw new Error("Token subject gecersiz");
  }

  return userId;
}

function toUserResponse(user: UserRow): Record<string, unknown> {
  return {
    id: user.id,
    email: normalizeEmail(user.email),
    name: asString(user.name),
    height: user.height ?? null,
    weight: user.weight ?? null,
    targetWeight: user.target_weight ?? null,
    birthDate: user.birth_date ?? null,
    gender: user.gender ?? null,
    activityLevel: user.activity_level ?? null,
    goal: user.goal ?? null,
    goalHistoryJson: user.goal_history_json ?? null,
    workoutLocation: user.workout_location ?? null,
    equipmentType: user.equipment_type ?? null,
    nutritionPreferencesJson: user.nutrition_preferences_json ?? null,
    aiMemorySummary: user.ai_memory_summary ?? null,
    motivationStatsJson: user.motivation_stats_json ?? null,
    premiumTier: user.premium_tier ?? "free",
    premiumExpiresAt: user.premium_expires_at ?? null,
    premiumPlan: user.premium_plan ?? null,
    premiumCancelAtPeriodEnd: user.premium_cancel_at_period_end ?? false,
    premiumCanceledAt: user.premium_canceled_at ?? null,
    createdAt: user.created_at ?? null,
    updatedAt: user.updated_at ?? null,
  };
}

async function findUserByEmail(email: string): Promise<UserRow | null> {
  const { data, error } = await supabase
    .from("users")
    .select("*")
    .eq("email", email)
    .maybeSingle();

  if (error) {
    throw new Error(`Database query failed: ${error.message}`);
  }

  return data;
}

async function findUserById(userId: number): Promise<UserRow | null> {
  const { data, error } = await supabase
    .from("users")
    .select("*")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`Database query failed: ${error.message}`);
  }

  return data;
}

async function createWelcomeNotification(userId: unknown): Promise<void> {
  await supabase.from("notifications").insert({
    user_id: userId,
    title: "PusulaFit'e hos geldin!",
    message: "Hedeflerine ulasmak icin ilk adimi attin. Hadi baslayalim!",
    type: "SYSTEM",
    is_read: false,
    created_at: new Date().toISOString(),
  });
}

async function createProfileWeightRecord(
  userId: unknown,
  weight: number,
): Promise<void> {
  await supabase.from("weight_records").insert({
    user_id: userId,
    weight,
    recorded_at: new Date().toISOString(),
    notes: "Profil guncellendi",
    created_at: new Date().toISOString(),
  });
}

async function handleRegister(req: Request): Promise<Response> {
  const body = await readJson(req);
  const email = normalizeEmail(body.email);
  const password = asString(body.password);
  const name = asString(body.name).trim();

  if (!email) return errorResponse("Email gerekli!");
  if (!validateEmail(email)) return errorResponse("Gecerli bir email adresi giriniz");
  if (!password) return errorResponse("Sifre bos olamaz");
  if (password.length < 8) return errorResponse("Sifre en az 8 karakter olmalidir");
  if (!name) return errorResponse("Ad bos olamaz");

  const existing = await findUserByEmail(email);
  if (existing) {
    return errorResponse("Bu email zaten kullaniliyor!");
  }

  const now = new Date().toISOString();
  const passwordHash = bcrypt.hashSync(password, 10);

  const { data, error } = await supabase
    .from("users")
    .insert({
      email,
      password: passwordHash,
      name,
      premium_tier: "free",
      premium_cancel_at_period_end: false,
      coaching_personality: "SUPPORTIVE",
      created_at: now,
      updated_at: now,
    })
    .select("*")
    .single();

  if (error) {
    if (error.code === "23505") {
      return errorResponse("Bu email zaten kullaniliyor!");
    }
    throw new Error(`Database insert failed: ${error.message}`);
  }

  await createWelcomeNotification(data.id).catch(() => undefined);

  return jsonResponse(
    {
      token: await buildJwt(data),
      user: toUserResponse(data),
    },
    201,
  );
}

async function handleLogin(req: Request): Promise<Response> {
  const body = await readJson(req);
  const email = normalizeEmail(body.email);
  const password = asString(body.password);

  if (!email) return errorResponse("Email gerekli!");
  if (!validateEmail(email)) return errorResponse("Gecerli bir email adresi giriniz");
  if (!password) return errorResponse("Sifre bos olamaz");

  const user = await findUserByEmail(email);
  if (!user) {
    return errorResponse("Email veya sifre hatali!");
  }

  const passwordHash = asString(user.password);
  const bcryptLike = /^\$2[aby]\$/.test(passwordHash);
  if (!bcryptLike || !bcrypt.compareSync(password, passwordHash)) {
    return errorResponse("Email veya sifre hatali!");
  }

  return jsonResponse({
    token: await buildJwt(user),
    user: toUserResponse(user),
  });
}

async function verifySocialIdentity(
  provider: string,
  idToken: string,
  requestedName: string,
): Promise<{ email: string; name: string; emailVerified: boolean }> {
  if (!idToken.trim()) throw new Error("Kimlik token'i bos.");

  const normalizedProvider = provider.trim().toLowerCase();
  if (normalizedProvider === "google") {
    const audiences = parseCsv(
      Deno.env.get("AUTH_GOOGLE_ALLOWED_CLIENT_IDS"),
      [
        "976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com",
        "976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com",
      ],
    );
    const { payload } = await jwtVerify(idToken, googleJwks, {
      issuer: ["https://accounts.google.com", "accounts.google.com"],
      audience: audiences,
      clockTolerance: 5,
    });
    return {
      email: normalizeEmail(payload.email),
      name: asString(payload.name),
      emailVerified: payload.email_verified === true ||
        asString(payload.email_verified).toLowerCase() === "true",
    };
  }

  if (normalizedProvider === "apple") {
    const audiences = parseCsv(
      Deno.env.get("AUTH_APPLE_ALLOWED_AUDIENCES"),
      ["com.eneskotay.fitnessapp", "com.eneskotay.pusulafit"],
    );
    const { payload } = await jwtVerify(idToken, appleJwks, {
      issuer: "https://appleid.apple.com",
      audience: audiences,
      clockTolerance: 5,
    });
    return {
      email: normalizeEmail(payload.email),
      name: requestedName.trim(),
      emailVerified: payload.email_verified === true ||
        asString(payload.email_verified).toLowerCase() === "true",
    };
  }

  throw new Error("Desteklenmeyen sosyal giris saglayicisi.");
}

function displayNameFromEmail(email: string): string {
  const localPart = email.split("@")[0] ?? "";
  const normalized = localPart.replace(/[._-]+/g, " ").trim();
  return normalized || "PusulaFit Kullanicisi";
}

async function handleSocialLogin(req: Request): Promise<Response> {
  const body = await readJson(req);
  const identity = await verifySocialIdentity(
    asString(body.provider),
    asString(body.idToken),
    asString(body.name),
  );

  if (!identity.emailVerified) {
    return errorResponse("Sosyal giris hesabinin e-posta adresi dogrulanmamis.");
  }
  if (!identity.email || !validateEmail(identity.email)) {
    return errorResponse("Sosyal giris saglayicisi dogrulanmis e-posta dondurmedi.");
  }

  const existing = await findUserByEmail(identity.email);
  if (existing) {
    const name = asString(existing.name).trim();
    if (!name && identity.name.trim()) {
      const { data, error } = await supabase
        .from("users")
        .update({
          name: identity.name.trim(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", existing.id)
        .select("*")
        .single();
      if (error) throw new Error(`Database update failed: ${error.message}`);
      return jsonResponse({ token: await buildJwt(data), user: toUserResponse(data) });
    }
    return jsonResponse({
      token: await buildJwt(existing),
      user: toUserResponse(existing),
    });
  }

  const now = new Date().toISOString();
  const randomPassword = crypto.randomUUID() + crypto.randomUUID();
  const { data, error } = await supabase
    .from("users")
    .insert({
      email: identity.email,
      password: bcrypt.hashSync(randomPassword, 10),
      name: identity.name.trim() || displayNameFromEmail(identity.email),
      premium_tier: "free",
      premium_cancel_at_period_end: false,
      coaching_personality: "SUPPORTIVE",
      created_at: now,
      updated_at: now,
    })
    .select("*")
    .single();

  if (error) throw new Error(`Database insert failed: ${error.message}`);
  await createWelcomeNotification(data.id).catch(() => undefined);
  return jsonResponse({ token: await buildJwt(data), user: toUserResponse(data) });
}

function resetCode(): string {
  return String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000)
    .padStart(6, "0");
}

async function sendResetEmail(email: string, code: string): Promise<void> {
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("MAIL_FROM") || "PusulaFit <noreply@pusulafit.app>";
  if (!resendApiKey) {
    console.warn("RESEND_API_KEY yok; sifre sifirlama kodu e-posta olarak gonderilemedi.");
    return;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: email,
      subject: "PusulaFit Sifre Sifirlama Kodu",
      html:
        `<h2>PusulaFit</h2><p>Sifre sifirlama talebinde bulundunuz.</p>` +
        `<p>Dogrulama kodunuz: <b style="font-size:24px;color:#CC7A4A">${code}</b></p>` +
        `<p>Kodunuz 15 dakika boyunca gecerlidir.</p>`,
    }),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(`Sifre sifirlama e-postasi gonderilemedi: ${detail}`);
  }
}

async function handleForgotPassword(req: Request): Promise<Response> {
  const body = await readJson(req);
  const email = normalizeEmail(body.email);
  const success = { message: "Dogrulama kodu e-posta adresinize gonderildi." };
  if (!email || !validateEmail(email)) return jsonResponse(success);

  const user = await findUserByEmail(email);
  if (!user) return jsonResponse(success);

  const code = resetCode();
  const expiryDate = new Date(Date.now() + 15 * 60 * 1000).toISOString();
  await supabase.from("password_reset_token").delete().eq("user_id", user.id);
  const { error } = await supabase.from("password_reset_token").insert({
    token: code,
    user_id: user.id,
    expiry_date: expiryDate,
  });
  if (error) throw new Error(`Database insert failed: ${error.message}`);

  await sendResetEmail(email, code);
  return jsonResponse(success);
}

async function findResetToken(email: string, code: string): Promise<UserRow | null> {
  const user = await findUserByEmail(email);
  if (!user) return null;

  const { data, error } = await supabase
    .from("password_reset_token")
    .select("*")
    .eq("token", code)
    .eq("user_id", user.id)
    .maybeSingle();
  if (error) throw new Error(`Database query failed: ${error.message}`);
  if (!data) return null;
  if (new Date(asString(data.expiry_date)).getTime() <= Date.now()) {
    throw new Error("Dogrulama kodunun suresi dolmus. Lutfen tekrar kod isteyin.");
  }
  return user;
}

async function handleVerifyResetCode(req: Request): Promise<Response> {
  const body = await readJson(req);
  const email = normalizeEmail(body.email);
  const code = asString(body.code).trim();
  const user = await findResetToken(email, code);
  if (!user) return errorResponse("Gecersiz veya hatali dogrulama kodu.", 400);
  return jsonResponse({ message: "Dogrulama kodu gecerli." });
}

async function handleResetPassword(req: Request): Promise<Response> {
  const body = await readJson(req);
  const email = normalizeEmail(body.email);
  const code = asString(body.code).trim();
  const newPassword = asString(body.newPassword);
  if (newPassword.length < 8) return errorResponse("Sifre en az 8 karakter olmalidir.");

  const user = await findResetToken(email, code);
  if (!user) return errorResponse("Gecersiz veya hatali dogrulama kodu.", 400);

  const { error } = await supabase
    .from("users")
    .update({
      password: bcrypt.hashSync(newPassword, 10),
      updated_at: new Date().toISOString(),
    })
    .eq("id", user.id);
  if (error) throw new Error(`Database update failed: ${error.message}`);

  await supabase.from("password_reset_token").delete().eq("token", code);
  return jsonResponse({
    message: "Sifreniz basariyla sifirlandi. Yeni sifrenizle giris yapabilirsiniz.",
  });
}

async function handleGetMe(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);

  if (!user) {
    return errorResponse("Kullanici bulunamadi!", 404);
  }

  return jsonResponse(toUserResponse(user));
}

async function handleUpdateProfile(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  if (!user) {
    return errorResponse("Kullanici bulunamadi!", 404);
  }

  const body = await readJson(req);
  const patch: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };

  if (hasOwn(body, "name")) patch.name = optionalTrimmedString(body.name);
  if (hasOwn(body, "height")) patch.height = optionalNumber(body.height, "height");
  if (hasOwn(body, "targetWeight")) {
    patch.target_weight = optionalNumber(body.targetWeight, "targetWeight");
  }
  if (hasOwn(body, "birthDate")) {
    patch.birth_date = optionalRawString(body.birthDate);
  }
  if (hasOwn(body, "gender")) patch.gender = optionalTrimmedString(body.gender);
  if (hasOwn(body, "activityLevel")) {
    patch.activity_level = optionalTrimmedString(body.activityLevel);
  }
  if (hasOwn(body, "workoutLocation")) {
    patch.workout_location = optionalTrimmedString(body.workoutLocation);
  }
  if (hasOwn(body, "equipmentType")) {
    patch.equipment_type = optionalTrimmedString(body.equipmentType);
  }
  if (hasOwn(body, "nutritionPreferencesJson")) {
    patch.nutrition_preferences_json = optionalRawString(
      body.nutritionPreferencesJson,
    );
  }
  if (hasOwn(body, "aiMemorySummary")) {
    patch.ai_memory_summary = optionalRawString(body.aiMemorySummary);
  }
  if (hasOwn(body, "motivationStatsJson")) {
    patch.motivation_stats_json = optionalRawString(body.motivationStatsJson);
  }

  if (hasOwn(body, "goal")) {
    const nextGoal = optionalTrimmedString(body.goal);
    patch.goal = nextGoal;
    if (nextGoal && user.goal !== nextGoal) {
      patch.goal_history_json = appendGoalHistory(
        user.goal_history_json,
        nextGoal,
      );
    }
  }

  let nextWeight: number | null | undefined;
  if (hasOwn(body, "weight")) {
    nextWeight = optionalNumber(body.weight, "weight");
    patch.weight = nextWeight;
  }

  const { data, error } = await supabase
    .from("users")
    .update(patch)
    .eq("id", userId)
    .select("*")
    .single();

  if (error) {
    throw new Error(`Database update failed: ${error.message}`);
  }

  if (
    typeof nextWeight === "number" &&
    Number(user.weight ?? NaN) !== nextWeight
  ) {
    await createProfileWeightRecord(userId, nextWeight).catch(() => undefined);
  }

  return jsonResponse(toUserResponse(data));
}

async function handleChangePassword(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  if (!user) {
    return errorResponse("Kullanici bulunamadi!", 404);
  }

  const body = await readJson(req);
  const currentPassword = asString(body.currentPassword).trim();
  const newPassword = asString(body.newPassword).trim();

  if (!currentPassword || !newPassword) {
    return errorResponse("Mevcut ve yeni sifre gerekli!");
  }
  if (newPassword.length < 8) {
    return errorResponse("Yeni sifre en az 8 karakter olmali!");
  }

  const passwordHash = asString(user.password);
  const bcryptLike = /^\$2[aby]\$/.test(passwordHash);
  if (!bcryptLike || !bcrypt.compareSync(currentPassword, passwordHash)) {
    return errorResponse("Mevcut sifre hatali!");
  }
  if (currentPassword === newPassword) {
    return errorResponse("Yeni sifre mevcut sifre ile ayni olamaz!");
  }

  const { error } = await supabase
    .from("users")
    .update({
      password: bcrypt.hashSync(newPassword, 10),
      updated_at: new Date().toISOString(),
    })
    .eq("id", userId);

  if (error) {
    throw new Error(`Database update failed: ${error.message}`);
  }

  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

async function handleDeleteMe(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  if (!user) {
    return errorResponse("Kullanici bulunamadi!", 404);
  }

  const { error } = await supabase.from("users").delete().eq("id", userId);
  if (error) {
    throw new Error(`Database delete failed: ${error.message}`);
  }

  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

function toWeightRecordResponse(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    weight: row.weight,
    bodyFatPercentage: row.body_fat_percentage ?? null,
    muscleMass: row.muscle_mass ?? null,
    recordedAt: row.recorded_at,
    notes: row.notes ?? null,
    createdAt: row.created_at ?? null,
  };
}

function toBodyMeasurementResponse(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: row.id,
    userId: row.user_id,
    date: row.date,
    chest: row.chest ?? null,
    waist: row.waist ?? null,
    hips: row.hips ?? null,
    leftArm: row.left_arm ?? null,
    rightArm: row.right_arm ?? null,
    leftLeg: row.left_leg ?? null,
    rightLeg: row.right_leg ?? null,
  };
}

async function handleCreateWeightRecord(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const now = new Date().toISOString();

  const weight = requiredNumber(body.weight, "weight");
  const { data, error } = await supabase
    .from("weight_records")
    .insert({
      user_id: userId,
      weight,
      body_fat_percentage: hasOwn(body, "bodyFatPercentage")
        ? optionalNumber(body.bodyFatPercentage, "bodyFatPercentage")
        : null,
      muscle_mass: hasOwn(body, "muscleMass")
        ? optionalNumber(body.muscleMass, "muscleMass")
        : null,
      recorded_at: optionalRawString(body.recordedAt) || now,
      notes: hasOwn(body, "notes") ? optionalRawString(body.notes) : null,
      created_at: now,
    })
    .select("*")
    .single();

  if (error) {
    throw new Error(`Database insert failed: ${error.message}`);
  }

  return jsonResponse(toWeightRecordResponse(data), 201);
}

async function handleListWeightRecords(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const url = new URL(req.url);
  const page = parsePositiveInt(url.searchParams.get("page"), 0);
  const size = Math.min(parsePositiveInt(url.searchParams.get("size"), 50), 200);
  const from = page * size;
  const to = from + size - 1;

  let query = supabase
    .from("weight_records")
    .select("*")
    .eq("user_id", userId)
    .order("recorded_at", { ascending: false })
    .range(from, to);

  const startDate = url.searchParams.get("startDate");
  const endDate = url.searchParams.get("endDate");
  if (startDate) query = query.gte("recorded_at", startDate);
  if (endDate) query = query.lte("recorded_at", endDate);

  const { data, error } = await query;
  if (error) {
    throw new Error(`Database query failed: ${error.message}`);
  }

  return jsonResponse((data ?? []).map(toWeightRecordResponse));
}

async function handleUpdateWeightRecord(
  req: Request,
  recordId: number,
): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const patch: Record<string, unknown> = {};

  if (hasOwn(body, "weight")) {
    patch.weight = requiredNumber(body.weight, "weight");
  }
  if (hasOwn(body, "bodyFatPercentage")) {
    patch.body_fat_percentage = optionalNumber(
      body.bodyFatPercentage,
      "bodyFatPercentage",
    );
  }
  if (hasOwn(body, "muscleMass")) {
    patch.muscle_mass = optionalNumber(body.muscleMass, "muscleMass");
  }
  if (hasOwn(body, "recordedAt")) {
    patch.recorded_at = optionalRawString(body.recordedAt);
  }
  if (hasOwn(body, "notes")) {
    patch.notes = optionalRawString(body.notes);
  }

  const { data, error } = await supabase
    .from("weight_records")
    .update(patch)
    .eq("id", recordId)
    .eq("user_id", userId)
    .select("*")
    .maybeSingle();

  if (error) {
    throw new Error(`Database update failed: ${error.message}`);
  }
  if (!data) {
    return errorResponse("Kilo kaydi bulunamadi!", 404);
  }

  return jsonResponse(toWeightRecordResponse(data));
}

async function handleDeleteWeightRecord(
  req: Request,
  recordId: number,
): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("weight_records")
    .delete()
    .eq("id", recordId)
    .eq("user_id", userId)
    .select("id")
    .maybeSingle();

  if (error) {
    throw new Error(`Database delete failed: ${error.message}`);
  }
  if (!data) {
    return errorResponse("Kilo kaydi bulunamadi!", 404);
  }

  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

async function handleCreateBodyMeasurement(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const date = optionalRawString(body.date);
  if (!date) {
    return errorResponse("Tarih bos olamaz");
  }

  const { data, error } = await supabase
    .from("body_measurements")
    .insert({
      user_id: userId,
      date,
      chest: hasOwn(body, "chest") ? optionalNumber(body.chest, "chest") : null,
      waist: hasOwn(body, "waist") ? optionalNumber(body.waist, "waist") : null,
      hips: hasOwn(body, "hips") ? optionalNumber(body.hips, "hips") : null,
      left_arm: hasOwn(body, "leftArm")
        ? optionalNumber(body.leftArm, "leftArm")
        : null,
      right_arm: hasOwn(body, "rightArm")
        ? optionalNumber(body.rightArm, "rightArm")
        : null,
      left_leg: hasOwn(body, "leftLeg")
        ? optionalNumber(body.leftLeg, "leftLeg")
        : null,
      right_leg: hasOwn(body, "rightLeg")
        ? optionalNumber(body.rightLeg, "rightLeg")
        : null,
      created_at: new Date().toISOString(),
    })
    .select("*")
    .single();

  if (error) {
    throw new Error(`Database insert failed: ${error.message}`);
  }

  return jsonResponse(toBodyMeasurementResponse(data), 201);
}

async function handleListBodyMeasurements(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const url = new URL(req.url);
  const page = parsePositiveInt(url.searchParams.get("page"), 0);
  const size = Math.min(parsePositiveInt(url.searchParams.get("size"), 50), 200);
  const from = page * size;
  const to = from + size - 1;

  let query = supabase
    .from("body_measurements")
    .select("*")
    .eq("user_id", userId)
    .order("date", { ascending: false })
    .range(from, to);

  const startDate = url.searchParams.get("startDate");
  const endDate = url.searchParams.get("endDate");
  if (startDate) query = query.gte("date", startDate);
  if (endDate) query = query.lte("date", endDate);

  const { data, error } = await query;
  if (error) {
    throw new Error(`Database query failed: ${error.message}`);
  }

  return jsonResponse((data ?? []).map(toBodyMeasurementResponse));
}

async function handleUpdateBodyMeasurement(
  req: Request,
  measurementId: number,
): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const patch: Record<string, unknown> = {};

  if (hasOwn(body, "date")) patch.date = optionalRawString(body.date);
  if (hasOwn(body, "chest")) patch.chest = optionalNumber(body.chest, "chest");
  if (hasOwn(body, "waist")) patch.waist = optionalNumber(body.waist, "waist");
  if (hasOwn(body, "hips")) patch.hips = optionalNumber(body.hips, "hips");
  if (hasOwn(body, "leftArm")) {
    patch.left_arm = optionalNumber(body.leftArm, "leftArm");
  }
  if (hasOwn(body, "rightArm")) {
    patch.right_arm = optionalNumber(body.rightArm, "rightArm");
  }
  if (hasOwn(body, "leftLeg")) {
    patch.left_leg = optionalNumber(body.leftLeg, "leftLeg");
  }
  if (hasOwn(body, "rightLeg")) {
    patch.right_leg = optionalNumber(body.rightLeg, "rightLeg");
  }

  const { data, error } = await supabase
    .from("body_measurements")
    .update(patch)
    .eq("id", measurementId)
    .eq("user_id", userId)
    .select("*")
    .maybeSingle();

  if (error) {
    throw new Error(`Database update failed: ${error.message}`);
  }
  if (!data) {
    return errorResponse("Vucut olcusu bulunamadi!", 404);
  }

  return jsonResponse(toBodyMeasurementResponse(data));
}

async function handleDeleteBodyMeasurement(
  req: Request,
  measurementId: number,
): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("body_measurements")
    .delete()
    .eq("id", measurementId)
    .eq("user_id", userId)
    .select("id")
    .maybeSingle();

  if (error) {
    throw new Error(`Database delete failed: ${error.message}`);
  }
  if (!data) {
    return errorResponse("Vucut olcusu bulunamadi!", 404);
  }

  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

function toMealResponse(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    name: row.name,
    mealType: row.meal_type,
    calories: row.calories,
    protein: row.protein ?? null,
    carbs: row.carbs ?? null,
    fat: row.fat ?? null,
    mealDate: row.meal_date,
    notes: row.notes ?? null,
    createdAt: row.created_at ?? null,
    updatedAt: row.updated_at ?? null,
  };
}

async function handleCreateMeal(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const name = asString(body.name).trim();
  const mealType = asString(body.mealType).trim();
  const calories = requiredInteger(body.calories, "calories");

  if (!name) return errorResponse("Yemek adi zorunludur.");
  if (!mealType) return errorResponse("Ogun tipi zorunludur.");
  if (calories < 0) return errorResponse("Gecerli bir kalori degeri girilmelidir.");

  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("meals")
    .insert({
      user_id: userId,
      name,
      meal_type: mealType,
      calories,
      protein: hasOwn(body, "protein") ? optionalNumber(body.protein, "protein") : null,
      carbs: hasOwn(body, "carbs") ? optionalNumber(body.carbs, "carbs") : null,
      fat: hasOwn(body, "fat") ? optionalNumber(body.fat, "fat") : null,
      meal_date: optionalRawString(body.mealDate) || now,
      notes: hasOwn(body, "notes") ? optionalRawString(body.notes) : null,
      created_at: now,
      updated_at: now,
    })
    .select("*")
    .single();

  if (error) {
    throw new Error(`Database insert failed: ${error.message}`);
  }

  return jsonResponse(toMealResponse(data), 201);
}

async function handleListMeals(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const url = new URL(req.url);
  const limitValue = url.searchParams.get("limit");
  const limit = limitValue
    ? Math.min(parsePositiveInt(limitValue, 50), 200)
    : undefined;

  let query = supabase
    .from("meals")
    .select("*")
    .eq("user_id", userId)
    .order("meal_date", { ascending: false });

  if (limit) {
    query = query.limit(limit);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error(`Database query failed: ${error.message}`);
  }

  return jsonResponse((data ?? []).map(toMealResponse));
}

async function handleMealsByDate(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const url = new URL(req.url);
  const date = url.searchParams.get("date");
  if (!date) {
    return errorResponse("Tarih gerekli");
  }
  const range = dayRange(date);

  const { data, error } = await supabase
    .from("meals")
    .select("*")
    .eq("user_id", userId)
    .gte("meal_date", range.start)
    .lt("meal_date", range.end)
    .order("meal_date", { ascending: false });

  if (error) {
    throw new Error(`Database query failed: ${error.message}`);
  }

  return jsonResponse((data ?? []).map(toMealResponse));
}

async function handleDailyCalories(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const url = new URL(req.url);
  const date = url.searchParams.get("date");
  if (!date) {
    return errorResponse("Tarih gerekli");
  }
  const range = dayRange(date);

  const { data, error } = await supabase
    .from("meals")
    .select("calories")
    .eq("user_id", userId)
    .gte("meal_date", range.start)
    .lt("meal_date", range.end);

  if (error) {
    throw new Error(`Database query failed: ${error.message}`);
  }

  const totalCalories = (data ?? []).reduce((sum, row) => {
    const calories = typeof row.calories === "number" ? row.calories : 0;
    return sum + calories;
  }, 0);

  return jsonResponse({ date, totalCalories });
}

async function handleUpdateMeal(req: Request, mealId: number): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const patch: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };

  if (hasOwn(body, "name")) {
    const name = optionalTrimmedString(body.name);
    if (name !== null && !name) return errorResponse("Yemek adi bos olamaz.");
    patch.name = name;
  }
  if (hasOwn(body, "mealType")) {
    const mealType = optionalTrimmedString(body.mealType);
    if (mealType !== null && !mealType) return errorResponse("Ogun tipi bos olamaz.");
    patch.meal_type = mealType;
  }
  if (hasOwn(body, "calories")) {
    const calories = requiredInteger(body.calories, "calories");
    if (calories < 0) return errorResponse("Kalori degeri 0'dan kucuk olamaz.");
    patch.calories = calories;
  }
  if (hasOwn(body, "protein")) patch.protein = optionalNumber(body.protein, "protein");
  if (hasOwn(body, "carbs")) patch.carbs = optionalNumber(body.carbs, "carbs");
  if (hasOwn(body, "fat")) patch.fat = optionalNumber(body.fat, "fat");
  if (hasOwn(body, "mealDate")) patch.meal_date = optionalRawString(body.mealDate);
  if (hasOwn(body, "notes")) patch.notes = optionalRawString(body.notes);

  const { data, error } = await supabase
    .from("meals")
    .update(patch)
    .eq("id", mealId)
    .eq("user_id", userId)
    .select("*")
    .maybeSingle();

  if (error) {
    throw new Error(`Database update failed: ${error.message}`);
  }
  if (!data) {
    return errorResponse("Yemek kaydi bulunamadi veya yetkiniz yok!", 404);
  }

  return jsonResponse(toMealResponse(data));
}

async function handleDeleteMeal(req: Request, mealId: number): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("meals")
    .delete()
    .eq("id", mealId)
    .eq("user_id", userId)
    .select("id")
    .maybeSingle();

  if (error) {
    throw new Error(`Database delete failed: ${error.message}`);
  }
  if (!data) {
    return errorResponse("Yemek kaydi bulunamadi veya yetkiniz yok!", 404);
  }

  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

async function handleDeleteAllMeals(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { error } = await supabase.from("meals").delete().eq("user_id", userId);
  if (error) {
    throw new Error(`Database delete failed: ${error.message}`);
  }

  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

function workoutSetFromRow(row: Record<string, unknown>): Record<string, unknown> {
  return {
    setNumber: row.set_number,
    setType: row.set_type ?? "NORMAL",
    reps: row.reps ?? null,
    weight: row.weight ?? null,
    rpe: row.rpe ?? null,
  };
}

async function workoutSets(workoutId: unknown): Promise<Record<string, unknown>[]> {
  const { data, error } = await supabase
    .from("workout_sets")
    .select("*")
    .eq("workout_id", workoutId)
    .order("set_number", { ascending: true });

  if (error) {
    throw new Error(`Database query failed: ${error.message}`);
  }

  return (data ?? []).map(workoutSetFromRow);
}

async function toWorkoutResponse(
  row: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const setDetails = await workoutSets(row.id);
  return {
    id: row.id,
    sessionId: row.workout_session_id ?? null,
    name: row.name,
    workoutType: row.workout_type ?? null,
    durationMinutes: row.duration_minutes ?? null,
    caloriesBurned: row.calories_burned ?? null,
    sets: row.sets ?? null,
    reps: row.reps ?? null,
    weight: row.weight ?? null,
    workoutDate: row.workout_date,
    notes: row.notes ?? null,
    createdAt: row.created_at ?? null,
    updatedAt: row.updated_at ?? null,
    setDetails: setDetails.length ? setDetails : null,
    muscleGroup: row.muscle_group ?? null,
    isSuperset: row.is_superset ?? false,
    supersetPartner: row.superset_partner ?? null,
    oneRepMax: row.one_rep_max ?? null,
    difficulty: row.difficulty ?? null,
  };
}

function resolveOneRepMax(body: Record<string, unknown>): number | null {
  const explicit = hasOwn(body, "oneRepMax")
    ? optionalNumber(body.oneRepMax, "oneRepMax")
    : null;
  if (explicit !== null && explicit > 0) return explicit;

  const setDetails = Array.isArray(body.setDetails) ? body.setDetails : [];
  const bestFromSets = setDetails.reduce((best, item) => {
    if (!item || typeof item !== "object") return best;
    const row = item as Record<string, unknown>;
    const weight = optionalNumber(row.weight ?? null, "weight");
    const reps = optionalInteger(row.reps ?? null, "reps");
    if (weight !== null && reps !== null && weight > 0 && reps > 0) {
      return Math.max(best, weight * (1 + reps / 30));
    }
    return best;
  }, 0);
  if (bestFromSets > 0) return bestFromSets;

  const weight = hasOwn(body, "weight") ? optionalNumber(body.weight, "weight") : null;
  const reps = hasOwn(body, "reps") ? optionalInteger(body.reps, "reps") : null;
  if (weight !== null && reps !== null && weight > 0 && reps > 0) {
    return weight * (1 + reps / 30);
  }

  return null;
}

function workoutInsertFromRequest(
  userId: number,
  body: Record<string, unknown>,
  sessionId: unknown = null,
): Record<string, unknown> {
  const name = asString(body.name).trim();
  if (!name) throw new Error("Antrenman adi zorunlu!");

  const durationMinutes = hasOwn(body, "durationMinutes")
    ? optionalInteger(body.durationMinutes, "durationMinutes")
    : null;
  const caloriesBurned = hasOwn(body, "caloriesBurned")
    ? optionalInteger(body.caloriesBurned, "caloriesBurned")
    : null;
  const sets = hasOwn(body, "sets") ? optionalInteger(body.sets, "sets") : null;
  const reps = hasOwn(body, "reps") ? optionalInteger(body.reps, "reps") : null;
  const weight = hasOwn(body, "weight") ? optionalNumber(body.weight, "weight") : null;

  if (durationMinutes !== null && durationMinutes < 0) throw new Error("Sure negatif olamaz!");
  if (caloriesBurned !== null && caloriesBurned < 0) throw new Error("Kalori negatif olamaz!");
  if (sets !== null && sets < 0) throw new Error("Set sayisi negatif olamaz!");
  if (reps !== null && reps < 0) throw new Error("Tekrar sayisi negatif olamaz!");
  if (weight !== null && weight < 0) throw new Error("Agirlik negatif olamaz!");

  const now = new Date().toISOString();
  return {
    user_id: userId,
    workout_session_id: sessionId,
    name,
    workout_type: trimOrNull(body.workoutType),
    duration_minutes: durationMinutes,
    calories_burned: caloriesBurned,
    sets,
    reps,
    weight,
    workout_date: optionalRawString(body.workoutDate) || now,
    notes: trimOrNull(body.notes),
    muscle_group: trimOrNull(body.muscleGroup),
    is_superset: body.isSuperset === true,
    superset_partner: trimOrNull(body.supersetPartner),
    difficulty: trimOrNull(body.difficulty),
    one_rep_max: resolveOneRepMax(body),
    created_at: now,
    updated_at: now,
  };
}

function workoutPatchFromRequest(body: Record<string, unknown>): Record<string, unknown> {
  const patch: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };

  if (hasOwn(body, "name")) {
    const name = asString(body.name).trim();
    if (!name) throw new Error("Antrenman adi bos olamaz!");
    patch.name = name;
  }
  if (hasOwn(body, "workoutType")) patch.workout_type = trimOrNull(body.workoutType);
  if (hasOwn(body, "durationMinutes")) {
    const value = optionalInteger(body.durationMinutes, "durationMinutes");
    if (value !== null && value < 0) throw new Error("Sure negatif olamaz!");
    patch.duration_minutes = value;
  }
  if (hasOwn(body, "caloriesBurned")) {
    const value = optionalInteger(body.caloriesBurned, "caloriesBurned");
    if (value !== null && value < 0) throw new Error("Kalori negatif olamaz!");
    patch.calories_burned = value;
  }
  if (hasOwn(body, "sets")) {
    const value = optionalInteger(body.sets, "sets");
    if (value !== null && value < 0) throw new Error("Set sayisi negatif olamaz!");
    patch.sets = value;
  }
  if (hasOwn(body, "reps")) {
    const value = optionalInteger(body.reps, "reps");
    if (value !== null && value < 0) throw new Error("Tekrar sayisi negatif olamaz!");
    patch.reps = value;
  }
  if (hasOwn(body, "weight")) {
    const value = optionalNumber(body.weight, "weight");
    if (value !== null && value < 0) throw new Error("Agirlik negatif olamaz!");
    patch.weight = value;
  }
  if (hasOwn(body, "workoutDate")) patch.workout_date = optionalRawString(body.workoutDate);
  if (hasOwn(body, "notes")) patch.notes = trimOrNull(body.notes);
  if (hasOwn(body, "muscleGroup")) patch.muscle_group = trimOrNull(body.muscleGroup);
  if (hasOwn(body, "isSuperset")) patch.is_superset = body.isSuperset === true;
  if (hasOwn(body, "supersetPartner")) patch.superset_partner = trimOrNull(body.supersetPartner);
  if (hasOwn(body, "difficulty")) patch.difficulty = trimOrNull(body.difficulty);
  if (hasOwn(body, "oneRepMax") || hasOwn(body, "setDetails")) {
    patch.one_rep_max = resolveOneRepMax(body);
  }

  return patch;
}

async function saveWorkoutSets(workoutId: unknown, details: unknown): Promise<void> {
  if (!Array.isArray(details) || details.length === 0) return;
  const rows = details.map((item, index) => {
    const detail = item && typeof item === "object"
      ? item as Record<string, unknown>
      : {};
    return {
      workout_id: workoutId,
      set_number: hasOwn(detail, "setNumber")
        ? optionalInteger(detail.setNumber, "setNumber") ?? index + 1
        : index + 1,
      set_type: trimOrNull(detail.setType) ?? "NORMAL",
      reps: hasOwn(detail, "reps") ? optionalInteger(detail.reps, "reps") : null,
      weight: hasOwn(detail, "weight") ? optionalNumber(detail.weight, "weight") : null,
      rpe: hasOwn(detail, "rpe") ? optionalNumber(detail.rpe, "rpe") : null,
      created_at: new Date().toISOString(),
    };
  });

  const { error } = await supabase.from("workout_sets").insert(rows);
  if (error) {
    throw new Error(`Database insert failed: ${error.message}`);
  }
}

async function handleCreateWorkout(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const { data, error } = await supabase
    .from("workouts")
    .insert(workoutInsertFromRequest(userId, body))
    .select("*")
    .single();

  if (error) throw new Error(`Database insert failed: ${error.message}`);
  await saveWorkoutSets(data.id, body.setDetails);
  return jsonResponse(await toWorkoutResponse(data), 201);
}

async function handleListWorkouts(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("workouts")
    .select("*")
    .eq("user_id", userId)
    .order("workout_date", { ascending: false });

  if (error) throw new Error(`Database query failed: ${error.message}`);
  return jsonResponse(await Promise.all((data ?? []).map(toWorkoutResponse)));
}

async function handleGetWorkout(req: Request, workoutId: number): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("workouts")
    .select("*")
    .eq("id", workoutId)
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw new Error(`Database query failed: ${error.message}`);
  if (!data) return errorResponse("Antrenman bulunamadi veya yetkiniz yok!", 404);
  return jsonResponse(await toWorkoutResponse(data));
}

async function handleUpdateWorkout(
  req: Request,
  workoutId: number,
): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const { data, error } = await supabase
    .from("workouts")
    .update(workoutPatchFromRequest(body))
    .eq("id", workoutId)
    .eq("user_id", userId)
    .select("*")
    .maybeSingle();

  if (error) throw new Error(`Database update failed: ${error.message}`);
  if (!data) return errorResponse("Antrenman bulunamadi veya yetkiniz yok!", 404);

  if (Array.isArray(body.setDetails) && body.setDetails.length > 0) {
    const deleteResult = await supabase
      .from("workout_sets")
      .delete()
      .eq("workout_id", workoutId);
    if (deleteResult.error) {
      throw new Error(`Database delete failed: ${deleteResult.error.message}`);
    }
    await saveWorkoutSets(workoutId, body.setDetails);
  }

  return jsonResponse(await toWorkoutResponse(data));
}

async function handleDeleteWorkout(req: Request, workoutId: number): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("workouts")
    .delete()
    .eq("id", workoutId)
    .eq("user_id", userId)
    .select("id")
    .maybeSingle();

  if (error) throw new Error(`Database delete failed: ${error.message}`);
  if (!data) return errorResponse("Antrenman bulunamadi veya yetkiniz yok!", 404);
  return new Response(null, { status: 204, headers: corsHeaders });
}

function exerciseToWorkoutBody(
  session: Record<string, unknown>,
  exercise: Record<string, unknown>,
): Record<string, unknown> {
  const completedSets = hasOwn(exercise, "completedSets")
    ? optionalInteger(exercise.completedSets, "completedSets")
    : null;
  const plannedSets = hasOwn(exercise, "plannedSets")
    ? optionalInteger(exercise.plannedSets, "plannedSets")
    : null;
  const sets = completedSets !== null && completedSets > 0 ? completedSets : plannedSets;
  const restSeconds = hasOwn(exercise, "restSeconds")
    ? optionalInteger(exercise.restSeconds, "restSeconds")
    : 90;
  const durationMinutes = sets !== null && sets > 0
    ? Math.max(1, Math.round((sets * ((restSeconds && restSeconds > 0 ? restSeconds : 90) + 45)) / 60))
    : null;

  return {
    name: exercise.name,
    workoutType: exercise.workoutType,
    muscleGroup: exercise.muscleGroup,
    sets,
    reps: exercise.reps,
    weight: exercise.weight,
    durationMinutes,
    workoutDate: session.finishedAt,
    notes: exercise.notes,
    difficulty: session.difficulty,
    setDetails: exercise.setDetails,
  };
}

async function handleCreateWorkoutSession(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const title = asString(body.title).trim();
  if (!title) throw new Error("Seans adi zorunlu!");
  const exercises = Array.isArray(body.exercises) ? body.exercises : [];
  if (exercises.length === 0) throw new Error("Seans en az bir egzersiz icermeli!");

  const now = new Date().toISOString();
  const { data: session, error: sessionError } = await supabase
    .from("workout_sessions")
    .insert({
      user_id: userId,
      title,
      started_at: hasOwn(body, "startedAt") ? optionalRawString(body.startedAt) : null,
      finished_at: optionalRawString(body.finishedAt) || now,
      duration_minutes: hasOwn(body, "durationMinutes")
        ? optionalInteger(body.durationMinutes, "durationMinutes")
        : null,
      planned_set_count: hasOwn(body, "plannedSetCount")
        ? optionalInteger(body.plannedSetCount, "plannedSetCount")
        : null,
      completed_set_count: hasOwn(body, "completedSetCount")
        ? optionalInteger(body.completedSetCount, "completedSetCount")
        : null,
      difficulty: trimOrNull(body.difficulty),
      notes: trimOrNull(body.notes),
      created_at: now,
      updated_at: now,
    })
    .select("*")
    .single();

  if (sessionError) throw new Error(`Database insert failed: ${sessionError.message}`);

  const workouts: Record<string, unknown>[] = [];
  try {
    for (const item of exercises) {
      if (!item || typeof item !== "object") continue;
      const exercise = item as Record<string, unknown>;
      if (!asString(exercise.name).trim()) continue;
      const workoutBody = exerciseToWorkoutBody(body, exercise);
      const insert = workoutInsertFromRequest(userId, workoutBody, session.id);
      const { data, error } = await supabase
        .from("workouts")
        .insert(insert)
        .select("*")
        .single();
      if (error) throw new Error(`Database insert failed: ${error.message}`);
      await saveWorkoutSets(data.id, exercise.setDetails);
      workouts.push(data);
    }
  } catch (error) {
    await supabase.from("workout_sessions").delete().eq("id", session.id);
    throw error;
  }

  if (workouts.length === 0) {
    await supabase.from("workout_sessions").delete().eq("id", session.id);
    throw new Error("Kaydedilecek egzersiz bulunamadi!");
  }

  return jsonResponse({
    id: session.id,
    title: session.title,
    startedAt: session.started_at ?? null,
    finishedAt: session.finished_at,
    durationMinutes: session.duration_minutes ?? null,
    plannedSetCount: session.planned_set_count ?? null,
    completedSetCount: session.completed_set_count ?? null,
    difficulty: session.difficulty ?? null,
    notes: session.notes ?? null,
    createdAt: session.created_at ?? null,
    updatedAt: session.updated_at ?? null,
    workouts: await Promise.all(workouts.map(toWorkoutResponse)),
  }, 201);
}

async function handleExerciseHistory(
  req: Request,
  exerciseName: string,
): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const decodedName = decodeURIComponent(exerciseName).trim().toLowerCase();
  if (!decodedName) throw new Error("Egzersiz adi bos olamaz!");

  const { data, error } = await supabase
    .from("workouts")
    .select("*")
    .eq("user_id", userId)
    .ilike("name", decodedName)
    .order("workout_date", { ascending: false });

  if (error) throw new Error(`Database query failed: ${error.message}`);
  return jsonResponse(await Promise.all((data ?? []).map(toWorkoutResponse)));
}

async function handlePersonalRecords(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("workouts")
    .select("name, one_rep_max, weight, reps")
    .eq("user_id", userId);

  if (error) throw new Error(`Database query failed: ${error.message}`);

  const records: Record<string, number> = {};
  for (const row of data ?? []) {
    const name = asString(row.name);
    if (!name) continue;
    let value = typeof row.one_rep_max === "number" ? row.one_rep_max : 0;
    if (value <= 0 && typeof row.weight === "number" && typeof row.reps === "number" && row.reps > 0) {
      value = row.weight * (1 + row.reps / 30);
    }
    if (value > 0) records[name] = Math.max(records[name] ?? 0, value);
  }

  return jsonResponse(records);
}

async function handleWorkoutStats(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const [{ data: workouts, error: workoutError }, { data: sessions, error: sessionError }] =
    await Promise.all([
      supabase.from("workouts").select("*").eq("user_id", userId),
      supabase.from("workout_sessions").select("*").eq("user_id", userId),
    ]);

  if (workoutError) throw new Error(`Database query failed: ${workoutError.message}`);
  if (sessionError) throw new Error(`Database query failed: ${sessionError.message}`);

  const rows = workouts ?? [];
  const totalWorkouts = rows.length;
  const totalSessions = (sessions ?? []).length || new Set(
    rows.map((row) => asString(row.workout_date).slice(0, 10)).filter(Boolean),
  ).size;
  const totalSets = rows.reduce((sum, row) => sum + (typeof row.sets === "number" ? row.sets : 0), 0);
  const totalVolume = rows.reduce((sum, row) => {
    const weight = typeof row.weight === "number" ? row.weight : 0;
    const reps = typeof row.reps === "number" ? row.reps : 0;
    const sets = typeof row.sets === "number" ? row.sets : 1;
    return sum + weight * reps * sets;
  }, 0);
  const totalCaloriesBurned = rows.reduce((sum, row) => {
    return sum + (typeof row.calories_burned === "number" ? row.calories_burned : 0);
  }, 0);
  const muscleCounts = new Map<string, number>();
  for (const row of rows) {
    const group = asString(row.muscle_group);
    if (group) muscleCounts.set(group, (muscleCounts.get(group) ?? 0) + 1);
  }
  const topMuscleGroup = [...muscleCounts.entries()]
    .sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

  return jsonResponse({
    totalWorkouts,
    totalSessions,
    totalSets,
    totalVolumeKg: Math.round(totalVolume),
    totalCaloriesBurned,
    topMuscleGroup,
  });
}

function isPremiumUser(user: UserRow | null): boolean {
  if (!user) return false;
  const tier = asString(user.premium_tier).toLowerCase();
  if (tier !== "premium") return false;
  const expiresAt = asString(user.premium_expires_at);
  if (!expiresAt) return true;
  return new Date(expiresAt).getTime() > Date.now();
}

function premiumStatusMap(user: UserRow, message?: string): Record<string, unknown> {
  const active = isPremiumUser(user);
  const planId = user.premium_plan ?? null;
  const cancelAtPeriodEnd = user.premium_cancel_at_period_end === true;
  return {
    tier: active ? "premium" : "free",
    isActive: active,
    expiresAt: user.premium_expires_at ?? null,
    planId,
    cancelAtPeriodEnd,
    canceledAt: user.premium_canceled_at ?? null,
    canCancel: active && asString(planId).toLowerCase() === "monthly" && !cancelAtPeriodEnd,
    ...(message ? { message } : {}),
  };
}

async function handlePremiumStatus(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  if (!user) return errorResponse("User not found", 404);

  if (
    asString(user.premium_tier).toLowerCase() === "premium" &&
    user.premium_expires_at &&
    new Date(asString(user.premium_expires_at)).getTime() <= Date.now()
  ) {
    const { data, error } = await supabase
      .from("users")
      .update({
        premium_tier: "free",
        premium_cancel_at_period_end: false,
        updated_at: new Date().toISOString(),
      })
      .eq("id", userId)
      .select("*")
      .single();
    if (error) throw new Error(`Database update failed: ${error.message}`);
    return jsonResponse(premiumStatusMap(data));
  }

  return jsonResponse(premiumStatusMap(user));
}

function normalizePlanId(planId: string): string {
  const normalized = planId.trim().toLowerCase();
  if (normalized.includes("year")) return "yearly";
  if (normalized.includes("month")) return "monthly";
  return normalized || "monthly";
}

async function handleUpgradePremiumIap(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  if (!user) return errorResponse("Kullanici bulunamadi.", 404);

  if (isPremiumUser(user)) {
    return jsonResponse(premiumStatusMap(user, "Premium zaten aktif."));
  }

  const body = await readJson(req);
  const platform = asString(body.platform).trim();
  const planId = normalizePlanId(asString(body.planId));
  const purchaseToken = asString(body.purchaseToken);
  const receiptData = asString(body.receiptData);
  const transactionId = asString(body.transactionId);

  if (!platform || !planId) {
    return errorResponse("platform ve planId zorunludur.");
  }

  const verifyMode = (Deno.env.get("IAP_VERIFY_MODE") ?? "dev").toLowerCase();
  if (verifyMode !== "dev" && verifyMode !== "apple") {
    return jsonResponse(
      { error: "IAP strict dogrulama Supabase function icin henuz aktif degil." },
      402,
    );
  }

  if (!purchaseToken && !receiptData && !transactionId) {
    return jsonResponse({ error: "Satinalma kaniti eksik." }, 402);
  }

  const months = planId === "yearly" ? 12 : 1;
  const expiresAt = addMonths(new Date(), months).toISOString();
  const { data, error } = await supabase
    .from("users")
    .update({
      premium_tier: "premium",
      premium_plan: planId,
      premium_expires_at: expiresAt,
      premium_cancel_at_period_end: false,
      premium_canceled_at: null,
      iap_original_transaction_id: transactionId || null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", userId)
    .select("*")
    .single();

  if (error) throw new Error(`Database update failed: ${error.message}`);
  return jsonResponse({
    ...premiumStatusMap(data, "Premium aktivasyonu basarili!"),
    transactionId,
  });
}

async function handleDowngradePremium(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  if (!user) return errorResponse("User not found", 404);
  if (!isPremiumUser(user)) return jsonResponse({ error: "Aktif premium uyelik bulunamadi." }, 409);
  if (asString(user.premium_plan).toLowerCase() !== "monthly") {
    return jsonResponse({ error: "Yillik plan satin alindiktan sonra iptal edilemez." }, 409);
  }
  if (user.premium_cancel_at_period_end === true) {
    return jsonResponse({ error: "Aylik plan icin donem sonu iptali zaten planlandi." }, 409);
  }

  const { data, error } = await supabase
    .from("users")
    .update({
      premium_cancel_at_period_end: true,
      premium_canceled_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", userId)
    .select("*")
    .single();

  if (error) throw new Error(`Database update failed: ${error.message}`);
  return jsonResponse(premiumStatusMap(
    data,
    "Iptal planlandi. Premium erisimin donem sonuna kadar devam edecek.",
  ));
}

async function consumeRateLimit(
  userId: number,
  scope: string,
  maxRequests: number,
  windowSeconds: number,
): Promise<{ ok: boolean; retryAfterSeconds?: number; remaining?: number }> {
  const now = new Date();
  const { data: current, error: readError } = await supabase
    .from("ai_rate_limits")
    .select("*")
    .eq("user_id", userId)
    .eq("scope", scope)
    .maybeSingle();
  if (readError) throw new Error(`Database query failed: ${readError.message}`);

  if (!current) {
    const { error } = await supabase.from("ai_rate_limits").insert({
      user_id: userId,
      scope,
      request_count: 1,
      window_start: now.toISOString(),
    });
    if (error) throw new Error(`Database insert failed: ${error.message}`);
    return { ok: true, remaining: Math.max(0, maxRequests - 1) };
  }

  const windowStart = new Date(asString(current.window_start));
  const elapsedSeconds = Math.floor((now.getTime() - windowStart.getTime()) / 1000);
  if (!Number.isFinite(elapsedSeconds) || elapsedSeconds >= windowSeconds) {
    const { error } = await supabase
      .from("ai_rate_limits")
      .update({ request_count: 1, window_start: now.toISOString() })
      .eq("id", current.id);
    if (error) throw new Error(`Database update failed: ${error.message}`);
    return { ok: true, remaining: Math.max(0, maxRequests - 1) };
  }

  const count = typeof current.request_count === "number" ? current.request_count : 0;
  if (count >= maxRequests) {
    return { ok: false, retryAfterSeconds: Math.max(1, windowSeconds - elapsedSeconds) };
  }

  const { error } = await supabase
    .from("ai_rate_limits")
    .update({ request_count: count + 1 })
    .eq("id", current.id);
  if (error) throw new Error(`Database update failed: ${error.message}`);
  return { ok: true, remaining: Math.max(0, maxRequests - count - 1) };
}

function extractJsonObject(text: string): Record<string, unknown> | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}

async function callGemini(prompt: string): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey || !apiKey.trim()) {
    throw new Error("GEMINI_API_KEY ayarlanmamis");
  }
  const model = Deno.env.get("GEMINI_MODEL") || "gemini-2.5-flash";
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.6 },
      }),
    },
  );
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data?.error?.message ?? "Gemini istegi basarisiz");
  }
  return data?.candidates?.[0]?.content?.parts?.[0]?.text?.toString() ?? "";
}

async function handleAiCoach(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  const premium = isPremiumUser(user);
  if (!premium) {
    const quota = await consumeRateLimit(userId, "coach_free_daily", 2, 86400);
    if (!quota.ok) {
      return jsonResponse({
        error: "Gunluk 2 ucretsiz AI koc hakkin doldu. Premium ile sinirsiz devam edebilirsin.",
        upgradeRequired: true,
      }, 403);
    }
  }
  const burst = await consumeRateLimit(userId, premium ? "coach_premium" : "coach", premium ? 75 : 10, premium ? 86400 : 300);
  if (!burst.ok) {
    return jsonResponse({ error: "Rate limit exceeded for AI coach", retryAfterSeconds: burst.retryAfterSeconds }, 429);
  }

  const body = await readJson(req);
  const question = asString(body.question).trim();
  const goal = asString(body.goal) || asString(user?.goal) || "maintain";
  const summary = JSON.stringify(body.dailySummary ?? {});
  const prompt = `Sen PusulaFit icin Turkce/English yanit verebilen fitness kocusun.
JSON disinda metin yazma. Sema:
{"todayFocus":"string","actionItems":["string"],"nutritionNote":"string","suggestedPrompts":["string"],"isAchievement":false}
Goal: ${goal}
Question: ${question}
Daily summary: ${summary}`;
  const text = await callGemini(prompt);
  const parsed = extractJsonObject(text);
  return jsonResponse({
    todayFocus: asString(parsed?.todayFocus) || "Bugun uygulanabilir tek bir odaga kilitlen.",
    actionItems: Array.isArray(parsed?.actionItems) ? parsed?.actionItems : ["10 dakika hareket et", "Protein ve su hedefini kontrol et"],
    nutritionNote: asString(parsed?.nutritionNote) || "Bugun tabagina protein ve lif eklemeyi hedefle.",
    suggestedPrompts: Array.isArray(parsed?.suggestedPrompts) ? parsed?.suggestedPrompts : ["Bugun ne calismaliyim?", "Beslenmemi yorumla"],
    isAchievement: parsed?.isAchievement === true,
    remainingFreeRequests: premium ? null : burst.remaining,
  });
}

async function handleAiNutrition(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  const premium = isPremiumUser(user);
  const limit = await consumeRateLimit(userId, premium ? "nutrition_premium" : "nutrition", premium ? 75 : 20, premium ? 86400 : 300);
  if (!limit.ok) {
    return jsonResponse({ error: "Too Many Requests", retryAfterSeconds: limit.retryAfterSeconds }, 429);
  }

  const body = await readJson(req);
  const task = asString(body.task);
  const message = asString(body.message).trim();
  const context = JSON.stringify(body.context ?? {});
  const prompt = `Beslenme asistani olarak kisa, pratik cevap ver. JSON disinda metin yazma.
Sema: {"reply":"string","meals":[{"name":"string","reason":"string","ingredients":["string"],"steps":["string"],"macros":{"kcal":0,"proteinG":0,"carbsG":0,"fatG":0},"prepMinutes":10,"tags":["string"],"warnings":[]}],"dailyPlan":[],"shoppingList":[],"followUpQuestions":["string"]}
Task: ${task}
Message: ${message}
Context: ${context}`;
  const text = await callGemini(prompt);
  const parsed = extractJsonObject(text);
  return jsonResponse({
    reply: asString(parsed?.reply) || "Beslenme hedefin icin porsiyon, protein ve toplam kaloriyi dengede tut.",
    meals: Array.isArray(parsed?.meals) ? parsed?.meals : [],
    dailyPlan: Array.isArray(parsed?.dailyPlan) ? parsed?.dailyPlan : [],
    shoppingList: Array.isArray(parsed?.shoppingList) ? parsed?.shoppingList : [],
    followUpQuestions: Array.isArray(parsed?.followUpQuestions) ? parsed?.followUpQuestions : [],
  });
}

async function handleAiWeeklyPlan(req: Request): Promise<Response> {
  await userIdFromAuthorization(req);
  const body = await readJson(req);
  const targetKcal = Number(body.targetKcal ?? 2000);
  const day = {
    breakfast: { name: "Yulaf, yogurt ve meyve", kcal: Math.round(targetKcal * 0.25), portionGrams: 300 },
    lunch: { name: "Tavuklu pilav/bowl", kcal: Math.round(targetKcal * 0.35), portionGrams: 450 },
    dinner: { name: "Protein, sebze ve karbonhidrat tabagi", kcal: Math.round(targetKcal * 0.30), portionGrams: 420 },
    snack: { name: "Kefir veya proteinli ara ogun", kcal: Math.round(targetKcal * 0.10), portionGrams: 200 },
  };
  return jsonResponse({ days: Array.from({ length: 7 }, () => day) });
}

async function handleAiSummarize(req: Request): Promise<Response> {
  await userIdFromAuthorization(req);
  const body = await readJson(req);
  const messages = Array.isArray(body.messages) ? body.messages.join("\n") : "";
  if (!messages.trim()) return jsonResponse({ summary: "" });
  const text = await callGemini(`Su fitness sohbetini 5 maddeden kisa ozetle:\n${messages}`);
  return jsonResponse({ summary: text.trim() });
}

async function handleAiFeedback(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  await supabase.from("ai_feedback").insert({
    user_id: userId,
    ai_response: asString(body.aiResponse),
    reaction: asString(body.reaction),
    task_mode: asString(body.taskMode) || null,
    personality: asString(body.personality) || null,
    user_question: asString(body.userQuestion) || null,
    reason: asString(body.reason) || null,
    coaching_preference: asString(body.coachingPreference) || null,
    created_at: new Date().toISOString(),
  }).catch(() => undefined);
  return jsonResponse({ status: "ok" });
}

async function handleAiInsights(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data } = await supabase
    .from("ai_insights")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(20);
  return jsonResponse(data ?? []);
}

function toRecipeResponse(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.external_id,
    name: row.name ?? "",
    description: row.description ?? "",
    category: row.category ?? "ana_yemek",
    servings: row.servings ?? 1,
    prepTimeMinutes: row.prep_time_minutes ?? 0,
    cookTimeMinutes: row.cook_time_minutes ?? 0,
    imageEmoji: row.image_emoji ?? "plate",
    kcalPerServing: row.kcal_per_serving ?? 0,
    proteinPerServing: row.protein_per_serving ?? 0,
    carbPerServing: row.carb_per_serving ?? 0,
    fatPerServing: row.fat_per_serving ?? 0,
    fiberPerServing: row.fiber_per_serving ?? 0,
    sugarPerServing: row.sugar_per_serving ?? 0,
    difficulty: row.difficulty ?? "orta",
    tags: jsonArray(row.tags),
    ingredients: jsonArray(row.ingredients),
    steps: jsonArray(row.steps),
  };
}

async function handleListRecipes(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("recipes")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(`Database query failed: ${error.message}`);
  return jsonResponse((data ?? []).map(toRecipeResponse));
}

function intOrDefault(value: unknown, fallback: number): number {
  if (value === undefined || value === null) return fallback;
  const parsed = optionalInteger(value, "value");
  return parsed === null ? fallback : parsed;
}

function numberOrDefault(value: unknown, fallback: number): number {
  if (value === undefined || value === null) return fallback;
  const parsed = optionalNumber(value, "value");
  return parsed === null ? fallback : parsed;
}

async function handleUpsertRecipe(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const externalId = asString(body.id).trim();
  if (!externalId) return errorResponse("id is required");

  const now = new Date().toISOString();
  const row = {
    user_id: userId,
    external_id: externalId,
    name: asString(body.name) || "",
    description: asString(body.description) || "",
    category: asString(body.category) || "ana_yemek",
    servings: intOrDefault(body.servings, 1),
    prep_time_minutes: intOrDefault(body.prepTimeMinutes, 0),
    cook_time_minutes: intOrDefault(body.cookTimeMinutes, 0),
    image_emoji: asString(body.imageEmoji) || "plate",
    kcal_per_serving: numberOrDefault(body.kcalPerServing, 0),
    protein_per_serving: numberOrDefault(body.proteinPerServing, 0),
    carb_per_serving: numberOrDefault(body.carbPerServing, 0),
    fat_per_serving: numberOrDefault(body.fatPerServing, 0),
    fiber_per_serving: numberOrDefault(body.fiberPerServing, 0),
    sugar_per_serving: numberOrDefault(body.sugarPerServing, 0),
    tags: toJsonText(body.tags),
    ingredients: toJsonText(body.ingredients),
    steps: toJsonText(body.steps),
    difficulty: asString(body.difficulty) || "orta",
    updated_at: now,
  };

  const { data: existing, error: existingError } = await supabase
    .from("recipes")
    .select("id")
    .eq("user_id", userId)
    .eq("external_id", externalId)
    .maybeSingle();
  if (existingError) throw new Error(`Database query failed: ${existingError.message}`);

  const query = existing
    ? supabase.from("recipes").update(row).eq("id", existing.id)
    : supabase.from("recipes").insert({ ...row, created_at: now });
  const { data, error } = await query.select("*").single();
  if (error) throw new Error(`Database upsert failed: ${error.message}`);
  return jsonResponse(toRecipeResponse(data), existing ? 200 : 201);
}

async function handleDeleteRecipe(
  req: Request,
  externalId: string,
): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("recipes")
    .delete()
    .eq("user_id", userId)
    .eq("external_id", decodeURIComponent(externalId))
    .select("id")
    .maybeSingle();
  if (error) throw new Error(`Database delete failed: ${error.message}`);
  if (!data) return errorResponse("Recipe not found", 404);
  return new Response(null, { status: 204, headers: corsHeaders });
}

function toExerciseResponse(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    muscleGroup: row.muscle_group,
    name: row.name,
    description: row.description ?? null,
    instructions: row.instructions ?? null,
    tips: row.tips ?? null,
  };
}

const fallbackExerciseCatalog: Record<string, Record<string, unknown>[]> = {
  CHEST: [
    { id: 9301, muscleGroup: "CHEST", name: "Bench Press", description: "Gogus kuvveti icin temel itis egzersizi.", instructions: "Kurek kemiklerini sikistir, bar kontrollu insin.", tips: "Dirsekleri omuz hizasinin cok disina acma." },
    { id: 9302, muscleGroup: "CHEST", name: "Incline Dumbbell Press", description: "Ust gogus odakli dumbbell press.", instructions: "Sehpada 30-45 derece aci kullan.", tips: "Agirligi yukarida birbirine carptirma." },
    { id: 9303, muscleGroup: "CHEST", name: "Push Up", description: "Vucut agirligi ile gogus ve triceps calisir.", instructions: "Govdeyi duz tut, kontrollu in ve it.", tips: "Zor gelirse diz uzeri varyasyon yap." },
  ],
  BACK: [
    { id: 9401, muscleGroup: "BACK", name: "Pull Up", description: "Sirt genisligi icin temel cekis.", instructions: "Gogsu bara yaklastir, omuzlari kulaga cekme.", tips: "Tam tekrar araligi kullan." },
    { id: 9402, muscleGroup: "BACK", name: "Barbell Row", description: "Orta sirt ve lat kuvveti.", instructions: "Belini sabit tut, bari karin altina cek.", tips: "Momentum yerine kontrollu cekis yap." },
    { id: 9403, muscleGroup: "BACK", name: "Lat Pulldown", description: "Lat odakli makine cekisi.", instructions: "Bari gogse dogru cek, dirsekleri asagi indir.", tips: "Boyun arkasina cekme." },
  ],
  LEGS: [
    { id: 9501, muscleGroup: "LEGS", name: "Squat", description: "Bacak kuvveti icin temel hareket.", instructions: "Dizleri ayak yonunde takip ettir, topuktan it.", tips: "Bel pozisyonunu koru." },
    { id: 9502, muscleGroup: "LEGS", name: "Romanian Deadlift", description: "Arka bacak ve kalca odakli hinge.", instructions: "Kalcalari geriye gotur, sirtini uzun tut.", tips: "Dizleri hafif kirik birak." },
    { id: 9503, muscleGroup: "LEGS", name: "Leg Press", description: "Makinede guvenli bacak itisi.", instructions: "Ayaklari platforma sabitle, dizleri kilitleme.", tips: "Belini pedden kaldirma." },
  ],
  SHOULDERS: [
    { id: 9601, muscleGroup: "SHOULDERS", name: "Overhead Press", description: "Omuz ve ust govde itis kuvveti.", instructions: "Karni sik, bari bas ustune it.", tips: "Belini asiri kamburlastirma." },
    { id: 9602, muscleGroup: "SHOULDERS", name: "Lateral Raise", description: "Yan omuz izolasyonu.", instructions: "Dirsekleri hafif kir, kontrollu kaldir.", tips: "Omuz hizasinin cok ustune cikma." },
    { id: 9603, muscleGroup: "SHOULDERS", name: "Face Pull", description: "Arka omuz ve skapula sagligi.", instructions: "Halati yuz hizasina cek.", tips: "Dirsekleri yukarida tut." },
  ],
  BICEPS: [
    { id: 9701, muscleGroup: "BICEPS", name: "Barbell Curl", description: "Biseps icin temel curl.", instructions: "Dirsekleri sabit tut, bari kontrollu kaldir.", tips: "Govdeyle sallanma." },
    { id: 9702, muscleGroup: "BICEPS", name: "Hammer Curl", description: "Brachialis ve on kol destegi.", instructions: "Avuclari birbirine bakacak sekilde kaldir.", tips: "Bilegi bukme." },
    { id: 9703, muscleGroup: "BICEPS", name: "Incline Dumbbell Curl", description: "Uzun bas odakli curl.", instructions: "Kollar geride basla, kontrollu curl yap.", tips: "Omuzu one alma." },
  ],
  TRICEPS: [
    { id: 9801, muscleGroup: "TRICEPS", name: "Triceps Pushdown", description: "Triceps izolasyonu.", instructions: "Dirsekleri govdeye yakin tut, asagi it.", tips: "Ust kol sabit kalsin." },
    { id: 9802, muscleGroup: "TRICEPS", name: "Close Grip Bench Press", description: "Triceps agirlikli itis.", instructions: "Tutuşu omuz genisligine yakin tut.", tips: "Bilekleri duz tut." },
    { id: 9803, muscleGroup: "TRICEPS", name: "Overhead Triceps Extension", description: "Uzun bas odakli triceps.", instructions: "Dirsekleri yukarida sabit tut.", tips: "Belini asiri acma." },
  ],
};

async function handleExerciseGroups(): Promise<Response> {
  const { data, error } = await supabase
    .from("exercises")
    .select("muscle_group")
    .order("muscle_group", { ascending: true });
  if (error) throw new Error(`Database query failed: ${error.message}`);
  const groups = [
    ...new Set((data ?? []).map((row) => asString(row.muscle_group)).filter(Boolean)),
  ];
  return jsonResponse(groups.length ? groups : Object.keys(fallbackExerciseCatalog));
}

async function handleExercises(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const muscleGroup = url.searchParams.get("muscleGroup")?.trim();
  if (!muscleGroup) return errorResponse("muscleGroup gerekli");

  const { data, error } = await supabase
    .from("exercises")
    .select("*")
    .ilike("muscle_group", muscleGroup)
    .order("name", { ascending: true });
  if (error) throw new Error(`Database query failed: ${error.message}`);
  const rows = (data ?? []).map(toExerciseResponse);
  return jsonResponse(rows.length ? rows : fallbackExerciseCatalog[muscleGroup.toUpperCase()] ?? []);
}

function toNotificationResponse(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    title: row.title,
    message: row.message,
    isRead: row.is_read ?? false,
    createdAt: row.created_at ?? null,
    type: row.type ?? null,
  };
}

async function handleListNotifications(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const url = new URL(req.url);
  const limit = Math.max(
    1,
    Math.min(parsePositiveInt(url.searchParams.get("limit"), 50), 100),
  );
  const { data, error } = await supabase
    .from("notifications")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(`Database query failed: ${error.message}`);
  return jsonResponse((data ?? []).map(toNotificationResponse));
}

async function handleRegisterNotificationDevice(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const token = asString(body.token).trim();
  const platform = asString(body.platform).trim();
  const appVersion = asString(body.appVersion).trim();
  if (!token || !platform) {
    return jsonResponse({ message: "token and platform are required" }, 400);
  }

  const now = new Date().toISOString();
  const { error } = await supabase.from("notification_devices").upsert({
    token,
    user_id: userId,
    platform,
    app_version: appVersion || null,
    active: true,
    updated_at: now,
  }, { onConflict: "token" });
  if (error) throw new Error(`Database upsert failed: ${error.message}`);
  return new Response(null, { status: 204, headers: corsHeaders });
}

async function handleUnregisterNotificationDevice(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const body = await readJson(req);
  const token = asString(body.token).trim();
  if (!token) return jsonResponse({ message: "token is required" }, 400);

  const { error } = await supabase
    .from("notification_devices")
    .update({ active: false, updated_at: new Date().toISOString() })
    .eq("token", token)
    .eq("user_id", userId);
  if (error) throw new Error(`Database update failed: ${error.message}`);
  return new Response(null, { status: 204, headers: corsHeaders });
}

async function handleUnreadNotificationCount(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { count, error } = await supabase
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("is_read", false);
  if (error) throw new Error(`Database query failed: ${error.message}`);
  return jsonResponse({ count: count ?? 0 });
}

async function handleMarkNotificationRead(
  req: Request,
  notificationId: number,
): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data, error } = await supabase
    .from("notifications")
    .update({ is_read: true })
    .eq("id", notificationId)
    .eq("user_id", userId)
    .select("id")
    .maybeSingle();
  if (error) throw new Error(`Database update failed: ${error.message}`);
  if (!data) return errorResponse("Notification not found", 404);
  return new Response(null, { status: 204, headers: corsHeaders });
}

async function handleAiLearningStats(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const [{ count: feedbackCount }, { data: prefs }] = await Promise.all([
    supabase
      .from("ai_feedback")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId),
    supabase
      .from("ai_user_preferences")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(10),
  ]);
  return jsonResponse({
    feedbackCount: feedbackCount ?? 0,
    learnedPreferences: prefs ?? [],
  });
}

async function handleAiWeeklyDigest(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const weekStart = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const [{ data: workouts }, { data: meals }, { data: weights }] = await Promise.all([
    supabase.from("workouts").select("*").eq("user_id", userId).gte("workout_date", weekStart),
    supabase.from("meals").select("*").eq("user_id", userId).gte("meal_date", weekStart),
    supabase.from("weight_records").select("*").eq("user_id", userId).gte("recorded_at", weekStart),
  ]);
  const totalCalories = (meals ?? []).reduce(
    (sum, row) => sum + (typeof row.calories === "number" ? row.calories : 0),
    0,
  );
  return jsonResponse({
    workoutCount: workouts?.length ?? 0,
    mealCount: meals?.length ?? 0,
    totalCalories,
    weightRecordCount: weights?.length ?? 0,
    summary: "Son 7 gunluk verilerin Supabase uzerinden hazirlandi.",
  });
}

async function handleAiProgressPrediction(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const { data } = await supabase
    .from("workouts")
    .select("name, one_rep_max, workout_date")
    .eq("user_id", userId)
    .order("workout_date", { ascending: true });
  return jsonResponse({
    trend: (data?.length ?? 0) >= 2 ? "data_available" : "insufficient_data",
    sampleCount: data?.length ?? 0,
    message: "Tahmin icin antrenman gecmisin Supabase'ten okundu.",
  });
}

async function handleAiCoachingPersonality(req: Request): Promise<Response> {
  const userId = await userIdFromAuthorization(req);
  const user = await findUserById(userId);
  if (!user) return errorResponse("Kullanici bulunamadi.", 404);
  if (req.method === "GET") {
    return jsonResponse({ personality: user.coaching_personality ?? "SUPPORTIVE" });
  }
  const body = await readJson(req);
  const personality = asString(body.personality).trim().toUpperCase();
  const allowed = new Set(["SUPPORTIVE", "TOUGH_LOVE", "ANALYTICAL"]);
  if (!allowed.has(personality)) return errorResponse("Gecersiz coaching personality.");
  const { data, error } = await supabase
    .from("users")
    .update({ coaching_personality: personality, updated_at: new Date().toISOString() })
    .eq("id", userId)
    .select("coaching_personality")
    .single();
  if (error) throw new Error(`Database update failed: ${error.message}`);
  return jsonResponse({ personality: data.coaching_personality });
}

function genericAiAnalysis(message: string): Response {
  return jsonResponse({
    status: "ok",
    message,
    generatedAt: new Date().toISOString(),
  });
}

function decodeJwsPayload(jws: string): Record<string, unknown> | null {
  const parts = jws.split(".");
  if (parts.length !== 3) return null;
  try {
    const normalized = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return JSON.parse(atob(padded));
  } catch {
    return null;
  }
}

function planFromProductId(productId: string): string | null {
  const normalized = productId.toLowerCase();
  if (normalized.includes("year")) return "yearly";
  if (normalized.includes("month")) return "monthly";
  return null;
}

async function handleAppleNotification(req: Request): Promise<Response> {
  const body = await readJson(req);
  const signedPayload = asString(body.signedPayload).trim();
  if (!signedPayload) return jsonResponse({ error: "signedPayload gerekli" }, 400);

  const payload = decodeJwsPayload(signedPayload);
  if (!payload) return jsonResponse({ status: "skipped" });

  const notificationType = asString(payload.notificationType);
  const subtype = asString(payload.subtype);
  const data = payload.data && typeof payload.data === "object"
    ? payload.data as Record<string, unknown>
    : {};
  const transactionInfo = decodeJwsPayload(asString(data.signedTransactionInfo));
  const originalTransactionId = asString(transactionInfo?.originalTransactionId);
  if (!originalTransactionId) return jsonResponse({ status: "skipped" });

  const { data: user, error: userError } = await supabase
    .from("users")
    .select("*")
    .eq("iap_original_transaction_id", originalTransactionId)
    .maybeSingle();
  if (userError) throw new Error(`Database query failed: ${userError.message}`);
  if (!user) return jsonResponse({ status: "skipped" });

  const productId = asString(transactionInfo?.productId);
  const expiresDate = Number(transactionInfo?.expiresDate ?? 0);
  const expiresAt = expiresDate > 0 ? new Date(expiresDate).toISOString() : null;
  const plan = (planFromProductId(productId) ?? asString(user.premium_plan)) || "monthly";
  const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };

  if (notificationType === "SUBSCRIBED" || notificationType === "DID_RENEW") {
    patch.premium_tier = "premium";
    patch.premium_plan = plan;
    patch.premium_expires_at = expiresAt;
    patch.premium_cancel_at_period_end = false;
    patch.premium_canceled_at = null;
  } else if (notificationType === "EXPIRED" || notificationType === "REVOKE" || notificationType === "REFUND") {
    patch.premium_tier = "free";
    patch.premium_cancel_at_period_end = false;
    patch.premium_canceled_at = new Date().toISOString();
  } else if (notificationType === "DID_CHANGE_RENEWAL_STATUS") {
    patch.premium_cancel_at_period_end = subtype === "AUTO_RENEW_DISABLED";
    patch.premium_canceled_at = subtype === "AUTO_RENEW_DISABLED"
      ? new Date().toISOString()
      : null;
  } else {
    return jsonResponse({ status: "skipped" });
  }

  const { error } = await supabase
    .from("users")
    .update(patch)
    .eq("id", user.id);
  if (error) throw new Error(`Database update failed: ${error.message}`);
  return jsonResponse({ status: "ok" });
}

async function route(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/functions\/v1/, "");
  const segments = path.split("/").filter(Boolean);

  if (req.method === "GET" && path === "/api/auth/test") {
    return jsonResponse({
      status: "ok",
      backend: "supabase-edge",
      timestamp: new Date().toISOString(),
    });
  }

  if (req.method === "POST" && path === "/api/auth/register") {
    return await handleRegister(req);
  }

  if (req.method === "POST" && path === "/api/auth/login") {
    return await handleLogin(req);
  }

  if (req.method === "POST" && path === "/api/auth/social") {
    return await handleSocialLogin(req);
  }

  if (req.method === "GET" && path === "/api/auth/me") {
    return await handleGetMe(req);
  }

  if (
    segments.length === 4 &&
    segments[0] === "api" &&
    segments[1] === "auth" &&
    segments[2] === "user" &&
    isNumericPathSegment(segments[3]) &&
    req.method === "GET"
  ) {
    const tokenUserId = await userIdFromAuthorization(req);
    const requestedUserId = Number.parseInt(segments[3], 10);
    if (tokenUserId !== requestedUserId) {
      return jsonResponse({ error: "Sadece kendi kullanici bilginize erisebilirsiniz." }, 403);
    }
    return await handleGetMe(req);
  }

  if (req.method === "PUT" && path === "/api/auth/me/profile") {
    return await handleUpdateProfile(req);
  }

  if (req.method === "PUT" && path === "/api/auth/me/password") {
    return await handleChangePassword(req);
  }

  if (req.method === "DELETE" && path === "/api/auth/me") {
    return await handleDeleteMe(req);
  }

  if (req.method === "POST" && path === "/api/auth/forgot-password") {
    return await handleForgotPassword(req);
  }

  if (req.method === "POST" && path === "/api/auth/verify-reset-code") {
    return await handleVerifyResetCode(req);
  }

  if (req.method === "POST" && path === "/api/auth/reset-password") {
    return await handleResetPassword(req);
  }

  if (path === "/api/tracking/me/weight-records") {
    if (req.method === "POST") return await handleCreateWeightRecord(req);
    if (req.method === "GET") return await handleListWeightRecords(req);
  }

  if (
    segments.length === 5 &&
    segments[0] === "api" &&
    segments[1] === "tracking" &&
    segments[2] === "me" &&
    segments[3] === "weight-records" &&
    isNumericPathSegment(segments[4])
  ) {
    const recordId = Number.parseInt(segments[4], 10);
    if (req.method === "PUT") {
      return await handleUpdateWeightRecord(req, recordId);
    }
    if (req.method === "DELETE") {
      return await handleDeleteWeightRecord(req, recordId);
    }
  }

  if (path === "/api/tracking/me/measurements") {
    if (req.method === "POST") return await handleCreateBodyMeasurement(req);
    if (req.method === "GET") return await handleListBodyMeasurements(req);
  }

  if (
    segments.length === 5 &&
    segments[0] === "api" &&
    segments[1] === "tracking" &&
    segments[2] === "me" &&
    segments[3] === "measurements" &&
    isNumericPathSegment(segments[4])
  ) {
    const measurementId = Number.parseInt(segments[4], 10);
    if (req.method === "PUT") {
      return await handleUpdateBodyMeasurement(req, measurementId);
    }
    if (req.method === "DELETE") {
      return await handleDeleteBodyMeasurement(req, measurementId);
    }
  }

  if (path === "/api/nutrition/me/meals") {
    if (req.method === "POST") return await handleCreateMeal(req);
    if (req.method === "GET") return await handleListMeals(req);
    if (req.method === "DELETE") return await handleDeleteAllMeals(req);
  }

  if (path === "/api/nutrition/me/meals/date" && req.method === "GET") {
    return await handleMealsByDate(req);
  }

  if (path === "/api/nutrition/me/calories" && req.method === "GET") {
    return await handleDailyCalories(req);
  }

  if (
    segments.length === 5 &&
    segments[0] === "api" &&
    segments[1] === "nutrition" &&
    segments[2] === "me" &&
    segments[3] === "meals" &&
    isNumericPathSegment(segments[4])
  ) {
    const mealId = Number.parseInt(segments[4], 10);
    if (req.method === "PUT") return await handleUpdateMeal(req, mealId);
    if (req.method === "DELETE") return await handleDeleteMeal(req, mealId);
  }

  if (path === "/api/workouts/me") {
    if (req.method === "POST") return await handleCreateWorkout(req);
    if (req.method === "GET") return await handleListWorkouts(req);
  }

  if (path === "/api/workouts/me/sessions" && req.method === "POST") {
    return await handleCreateWorkoutSession(req);
  }

  if (path === "/api/workouts/me/personal-records" && req.method === "GET") {
    return await handlePersonalRecords(req);
  }

  if (path === "/api/workouts/me/stats" && req.method === "GET") {
    return await handleWorkoutStats(req);
  }

  if (
    segments.length === 6 &&
    segments[0] === "api" &&
    segments[1] === "workouts" &&
    segments[2] === "me" &&
    segments[3] === "exercise" &&
    segments[5] === "history" &&
    req.method === "GET"
  ) {
    return await handleExerciseHistory(req, segments[4]);
  }

  if (
    segments.length === 4 &&
    segments[0] === "api" &&
    segments[1] === "workouts" &&
    segments[2] === "me" &&
    isNumericPathSegment(segments[3])
  ) {
    const workoutId = Number.parseInt(segments[3], 10);
    if (req.method === "GET") return await handleGetWorkout(req, workoutId);
    if (req.method === "PUT") return await handleUpdateWorkout(req, workoutId);
    if (req.method === "DELETE") return await handleDeleteWorkout(req, workoutId);
  }

  if (path === "/api/user/premium-status" && req.method === "GET") {
    return await handlePremiumStatus(req);
  }

  if (path === "/api/user/upgrade-premium" && req.method === "POST") {
    return jsonResponse({
      error: "Bu endpoint artik kullanilmiyor.",
      message: "Mobil odemeler icin /api/user/upgrade-premium/iap endpoint'ini kullanin.",
    }, 410);
  }

  if (path === "/api/user/upgrade-premium/iap" && req.method === "POST") {
    return await handleUpgradePremiumIap(req);
  }

  if (path === "/api/user/downgrade-premium" && req.method === "POST") {
    return await handleDowngradePremium(req);
  }

  if (path === "/api/apple/notifications" && req.method === "POST") {
    return await handleAppleNotification(req);
  }

  if (path === "/api/recipes") {
    if (req.method === "GET") return await handleListRecipes(req);
    if (req.method === "POST") return await handleUpsertRecipe(req);
  }

  if (
    segments.length === 3 &&
    segments[0] === "api" &&
    segments[1] === "recipes" &&
    req.method === "DELETE"
  ) {
    return await handleDeleteRecipe(req, segments[2]);
  }

  if (path === "/api/exercises/groups" && req.method === "GET") {
    return await handleExerciseGroups();
  }

  if (path === "/api/exercises" && req.method === "GET") {
    return await handleExercises(req);
  }

  if (path === "/api/exercises" && req.method === "POST") {
    return jsonResponse({ error: "Egzersiz katalog guncellemesi API uzerinden kapatildi." }, 403);
  }

  if (
    segments.length === 3 &&
    segments[0] === "api" &&
    segments[1] === "exercises" &&
    isNumericPathSegment(segments[2]) &&
    req.method === "PUT"
  ) {
    return jsonResponse({ error: "Egzersiz katalog guncellemesi API uzerinden kapatildi." }, 403);
  }

  if (path === "/api/notifications") {
    if (req.method === "GET") return await handleListNotifications(req);
  }

  if (path === "/api/notifications/devices") {
    if (req.method === "POST") return await handleRegisterNotificationDevice(req);
    if (req.method === "DELETE") return await handleUnregisterNotificationDevice(req);
  }

  if (path === "/api/notifications/unread-count" && req.method === "GET") {
    return await handleUnreadNotificationCount(req);
  }

  if (
    segments.length === 4 &&
    segments[0] === "api" &&
    segments[1] === "notifications" &&
    isNumericPathSegment(segments[2]) &&
    segments[3] === "read" &&
    req.method === "PATCH"
  ) {
    return await handleMarkNotificationRead(req, Number.parseInt(segments[2], 10));
  }

  if (path === "/api/ai/coach" && req.method === "POST") {
    return await handleAiCoach(req);
  }

  if (path === "/api/ai/nutrition" && req.method === "POST") {
    return await handleAiNutrition(req);
  }

  if (path === "/api/ai/nutrition/feedback" && req.method === "POST") {
    return await handleAiFeedback(req);
  }

  if (path === "/api/ai/nutrition/weekly-plan" && req.method === "POST") {
    return await handleAiWeeklyPlan(req);
  }

  if (path === "/api/ai/summarize" && req.method === "POST") {
    return await handleAiSummarize(req);
  }

  if (path === "/api/ai/feedback" && req.method === "POST") {
    return await handleAiFeedback(req);
  }

  if (path === "/api/ai/insights" && req.method === "GET") {
    return await handleAiInsights(req);
  }

  if (path === "/api/ai/progress-prediction" && req.method === "GET") {
    return await handleAiProgressPrediction(req);
  }

  if (path === "/api/ai/learning-stats" && req.method === "GET") {
    return await handleAiLearningStats(req);
  }

  if (path === "/api/ai/weekly-digest" && req.method === "GET") {
    return await handleAiWeeklyDigest(req);
  }

  if (path === "/api/ai/coaching-personality" && (req.method === "GET" || req.method === "POST")) {
    return await handleAiCoachingPersonality(req);
  }

  if (
    path === "/api/ai/habit-analysis" ||
    path === "/api/ai/social-insights" ||
    path === "/api/ai/workout/deload-check" ||
    path === "/api/ai/workout/volume-analysis"
  ) {
    await userIdFromAuthorization(req);
    return genericAiAnalysis("Analiz Supabase verileriyle hazir.");
  }

  if (
    segments.length === 5 &&
    segments[0] === "api" &&
    segments[1] === "ai" &&
    segments[2] === "workout" &&
    (segments[3] === "plateau" || segments[3] === "pr-prediction") &&
    req.method === "GET"
  ) {
    await userIdFromAuthorization(req);
    return genericAiAnalysis(`${decodeURIComponent(segments[4])} icin analiz hazir.`);
  }

  if (
    segments.length === 5 &&
    segments[0] === "api" &&
    segments[1] === "ai" &&
    segments[2] === "workout" &&
    segments[3] === "muscle-group-plateau" &&
    req.method === "GET"
  ) {
    await userIdFromAuthorization(req);
    return genericAiAnalysis(`${decodeURIComponent(segments[4])} kas grubu icin analiz hazir.`);
  }

  if (path === "/api/ai/generate-program" && req.method === "POST") {
    return await handleAiCoach(req);
  }

  if (path === "/api/ai/form-check" && req.method === "POST") {
    await userIdFromAuthorization(req);
    return genericAiAnalysis("Form kontrolu icin gorsel/video analizi Supabase gecisinde sinirli modda.");
  }

  if (
    (path === "/api/ai/nutrition/scan-label" ||
      path === "/api/ai/nutrition/analyze-image" ||
      path === "/api/ai/vision") &&
    req.method === "POST"
  ) {
    await userIdFromAuthorization(req);
    return jsonResponse({
      error: "Gorsel AI analizi Supabase gecisinde henuz aktif degil.",
    }, 501);
  }

  return jsonResponse(
    {
      error: "Not Found",
      path,
    },
    404,
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  try {
    return await route(req);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Bilinmeyen hata";
    const lower = message.toLowerCase();
    const status = lower.includes("authorization") || lower.includes("token")
      ? 401
      : 400;

    return errorResponse(message, status);
  }
});
