// ============================================================
// ضع بيانات مشروعك من Supabase هنا (Project Settings > API)
// ============================================================
const SUPABASE_URL = "https://lbbkzrqevnicdyiddazm.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxiYmt6cnFldm5pY2R5aWRkYXptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNTUzNDcsImV4cCI6MjEwMzkzMTM0N30.KckGMt6ljJ_C0-aakZTaunsjbcfMD_iF-ivv7lbcdbc";

// عميل Supabase متاح لكل الصفحات عبر window.sb
window.sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// تجزئة الباسورد (SHA-256) قبل تخزينه أو مقارنته — أفضل من نص صريح
// (للاستخدام الإنتاجي الكامل يُفضّل التحويل إلى Supabase Auth لاحقًا)
async function hashPassword(plain){
  const enc = new TextEncoder().encode(plain);
  const buf = await crypto.subtle.digest('SHA-256', enc);
  return Array.from(new Uint8Array(buf)).map(b=>b.toString(16).padStart(2,'0')).join('');
}

// تحقق أن الباسورد يحتوي على حرف صغير وحرف كبير ورقم و8 خانات على الأقل
function isStrongPassword(pw){
  return /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/.test(pw);
}
