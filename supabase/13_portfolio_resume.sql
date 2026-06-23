-- Portfolio resume upload (one CV per user, shown in portfolio section)
alter table public.users
  add column if not exists resume_url text,
  add column if not exists resume_file_name text;

comment on column public.users.resume_url is 'Public URL of uploaded resume/CV (PDF/DOC/DOCX)';
comment on column public.users.resume_file_name is 'Original filename of the uploaded resume';
