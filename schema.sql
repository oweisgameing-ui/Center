-- ============================================================
-- سنتر المدرسين — إعداد قاعدة بيانات Supabase
-- شغّل هذا الملف كامل في: Supabase Dashboard > SQL Editor > New query
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- المدرسين ----------
create table if not exists teachers (
  id uuid primary key default gen_random_uuid(),
  center_name text not null default 'سنتر الأستاذ',
  password_hash text not null,          -- SHA-256 hex (يتم عمله من الواجهة قبل الإرسال)
  default_price numeric not null default 250,
  created_at timestamptz not null default now()
);

-- ---------- المراحل الدراسية ----------
create table if not exists stages (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references teachers(id) on delete cascade,
  name text not null,
  price numeric,                        -- لو فارغ يُستخدم السعر الافتراضي للمدرس
  created_at timestamptz not null default now()
);

-- ---------- الطلاب ----------
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references teachers(id) on delete cascade,
  stage_id uuid references stages(id) on delete set null,
  name text not null,
  email text not null unique,
  phone text not null,
  password_hash text not null,          -- SHA-256 hex
  status text not null default 'pending' check (status in ('pending','active')),
  created_at timestamptz not null default now()
);

-- ---------- الحصص (بمواعيد محددة، مثلاً 8 حصص بالشهر) ----------
create table if not exists sessions (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references teachers(id) on delete cascade,
  stage_id uuid not null references stages(id) on delete cascade,
  name text not null,
  session_date date not null,
  session_time time not null,
  code text not null,                   -- كود الحضور الذي يحدده المدرس لهذه الحصة تحديدًا
  created_at timestamptz not null default now()
);

-- ---------- سجل الحضور ----------
create table if not exists attendance (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references sessions(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  method text not null default 'code' check (method in ('code','qr')),
  attended_at timestamptz not null default now(),
  unique (session_id, student_id)
);

-- ---------- الدفع الشهري ----------
create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  month text not null,                  -- بصيغة YYYY-MM
  amount numeric,
  paid boolean not null default false,
  paid_at timestamptz,
  reminder_sent_at timestamptz,
  unique (student_id, month)
);

-- ---------- الامتحانات ----------
create table if not exists exams (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references teachers(id) on delete cascade,
  session_id uuid not null references sessions(id) on delete cascade,
  stage_id uuid not null references stages(id) on delete cascade,
  title text not null,
  max_score numeric not null default 100,
  created_at timestamptz not null default now()
);

-- ---------- درجات الطلاب في كل امتحان ----------
create table if not exists exam_grades (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references exams(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  score numeric,                         -- NULL = لم تُرصد درجته بعد
  absent boolean not null default false, -- true = غائب عن الامتحان
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exam_id, student_id)
);

-- ---------- فهارس مساعدة ----------
create index if not exists idx_students_teacher on students(teacher_id);
create index if not exists idx_students_stage on students(stage_id);
create index if not exists idx_sessions_teacher on sessions(teacher_id);
create index if not exists idx_sessions_stage_date on sessions(stage_id, session_date);
create index if not exists idx_attendance_session on attendance(session_id);
create index if not exists idx_attendance_student on attendance(student_id);
create index if not exists idx_payments_student_month on payments(student_id, month);
create index if not exists idx_exams_teacher on exams(teacher_id);
create index if not exists idx_exams_session on exams(session_id);
create index if not exists idx_exams_stage on exams(stage_id);
create index if not exists idx_exam_grades_exam on exam_grades(exam_id);
create index if not exists idx_exam_grades_student on exam_grades(student_id);

-- ============================================================
-- Row Level Security
-- التطبيق واجهة أمامية بالكامل (بدون سيرفر خاص بك) وتتصل مباشرة
-- بـ Supabase بمفتاح anon، فالتحقق من الباسورد يتم من المتصفح.
-- هذا مناسب للتجربة والاستخدام الداخلي، لكنه ليس بنفس أمان
-- Supabase Auth الحقيقي (JWT لكل مستخدم). للاستخدام الإنتاجي
-- الموصى به لاحقًا: استبدال هذا بـ Supabase Auth + سياسات مبنية
-- على auth.uid(). في الوقت الحالي السياسات أدناه تسمح بالقراءة
-- والكتابة عبر مفتاح anon حتى يعمل التطبيق كما هو مطلوب.
-- ============================================================

alter table teachers enable row level security;
alter table stages enable row level security;
alter table students enable row level security;
alter table sessions enable row level security;
alter table attendance enable row level security;
alter table payments enable row level security;
alter table exams enable row level security;
alter table exam_grades enable row level security;

create policy "anon full access teachers" on teachers for all using (true) with check (true);
create policy "anon full access stages" on stages for all using (true) with check (true);
create policy "anon full access students" on students for all using (true) with check (true);
create policy "anon full access sessions" on sessions for all using (true) with check (true);
create policy "anon full access attendance" on attendance for all using (true) with check (true);
create policy "anon full access payments" on payments for all using (true) with check (true);
create policy "anon full access exams" on exams for all using (true) with check (true);
create policy "anon full access exam_grades" on exam_grades for all using (true) with check (true);

-- ============================================================
-- (اختياري) لإنشاء أول مدرس يدويًا بدل صفحة "إنشاء حساب مدرس":
-- الباسورد هنا SHA-256("Teacher123") كمثال — غيّره بهاش الباسورد
-- اللي هتحسبه صفحة تسجيل الدخول (اعرضه في Console وانسخه هنا)
-- ============================================================
-- insert into teachers (center_name, password_hash, default_price)
-- values ('سنتر الأستاذ أحمد', '<ضع هنا الهاش الناتج من الواجهة>', 250);