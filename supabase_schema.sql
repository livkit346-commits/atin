-- Drop existing tables to clean up schema mismatch from earlier runs
drop table if exists public.attendances cascade;
drop table if exists public.attendance_sessions cascade;
drop table if exists public.organization_members cascade;
drop table if exists public.organizations cascade;
drop table if exists public.profiles cascade;

-- 1. Profiles table for users (students and admins)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  name text not null,
  email text not null unique,
  gender text check (gender in ('Male', 'Female')),
  department text,
  level text,
  school text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for profiles
alter table public.profiles enable row level security;

-- Profiles policies
drop policy if exists "Allow public read access to profiles" on public.profiles;
create policy "Allow public read access to profiles" on public.profiles
  for select using (true);

drop policy if exists "Allow users to update their own profile" on public.profiles;
create policy "Allow users to update their own profile" on public.profiles
  for update using (auth.uid() = id);

-- Trigger to automatically create a profile for new auth users
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, email, gender, department, level, school)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'User'),
    new.email,
    new.raw_user_meta_data->>'gender',
    new.raw_user_meta_data->>'department',
    new.raw_user_meta_data->>'level',
    new.raw_user_meta_data->>'school'
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. Organizations table
create table if not exists public.organizations (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  type text default 'SIWES Attendance Group' check (type = 'SIWES Attendance Group'),
  created_by uuid references public.profiles(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for organizations
alter table public.organizations enable row level security;

drop policy if exists "Anyone can read organizations" on public.organizations;
create policy "Anyone can read organizations" on public.organizations
  for select using (true);

drop policy if exists "Anyone can create an organization" on public.organizations;
create policy "Anyone can create an organization" on public.organizations
  for insert with check (auth.uid() = created_by);


-- 3. Organization Members mapping table
create table if not exists public.organization_members (
  id uuid default gen_random_uuid() primary key,
  organization_id uuid references public.organizations(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text check (role in ('admin', 'member')) default 'member',
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (organization_id, user_id)
);

-- Enable RLS for organization_members
alter table public.organization_members enable row level security;

drop policy if exists "Anyone can view members" on public.organization_members;
create policy "Anyone can view members" on public.organization_members
  for select using (true);

drop policy if exists "Users can join organizations as members" on public.organization_members;
create policy "Users can join organizations as members" on public.organization_members
  for insert with check (auth.uid() = user_id AND role = 'member');

drop policy if exists "Organization admins can update member roles" on public.organization_members;
create policy "Organization admins can update member roles" on public.organization_members
  for update using (
    exists (
      select 1 from public.organization_members admin_check
      where admin_check.organization_id = organization_members.organization_id
        and admin_check.user_id = auth.uid()
        and admin_check.role = 'admin'
    )
  );

-- Trigger to automatically add organization creator as admin member
create or replace function public.handle_new_organization()
returns trigger as $$
begin
  insert into public.organization_members (organization_id, user_id, role)
  values (new.id, new.created_by, 'admin');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_organization_created on public.organizations;
create trigger on_organization_created
  after insert on public.organizations
  for each row execute procedure public.handle_new_organization();


-- 4. Attendance Sessions created by Admins
create table if not exists public.attendance_sessions (
  id uuid default gen_random_uuid() primary key,
  organization_id uuid references public.organizations(id) on delete cascade not null,
  admin_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  auth_type text check (auth_type in ('gps', 'ble', 'both')) default 'gps',
  -- GPS Config
  latitude double precision,
  longitude double precision,
  radius_meters integer default 50,
  -- BLE Config
  ble_uuid uuid,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  expires_at timestamp with time zone not null
);

-- Enable RLS for attendance_sessions
alter table public.attendance_sessions enable row level security;

drop policy if exists "Members can read sessions of their organization" on public.attendance_sessions;
create policy "Members can read sessions of their organization" on public.attendance_sessions
  for select using (
    exists (
      select 1 from public.organization_members
      where organization_members.organization_id = attendance_sessions.organization_id
        and organization_members.user_id = auth.uid()
    )
  );

drop policy if exists "Admins can insert sessions to their organization" on public.attendance_sessions;
create policy "Admins can insert sessions to their organization" on public.attendance_sessions
  for insert with check (
    exists (
      select 1 from public.organization_members
      where organization_members.organization_id = attendance_sessions.organization_id
        and organization_members.user_id = auth.uid()
        and organization_members.role = 'admin'
    )
  );

drop policy if exists "Admins can update sessions in their organization" on public.attendance_sessions;
create policy "Admins can update sessions in their organization" on public.attendance_sessions
  for update using (
    exists (
      select 1 from public.organization_members
      where organization_members.organization_id = attendance_sessions.organization_id
        and organization_members.user_id = auth.uid()
        and organization_members.role = 'admin'
    )
  );


-- 5. Attendances log
create table if not exists public.attendances (
  id uuid default gen_random_uuid() primary key,
  student_id uuid references public.profiles(id) on delete cascade not null,
  session_id uuid references public.attendance_sessions(id) on delete cascade not null,
  check_in timestamp with time zone default timezone('utc'::text, now()) not null,
  check_out timestamp with time zone,
  date date default current_date not null,
  unique (student_id, session_id, date)
);

-- Enable RLS for attendances
alter table public.attendances enable row level security;

drop policy if exists "Students can view their own attendance" on public.attendances;
create policy "Students can view their own attendance" on public.attendances
  for select using (student_id = auth.uid());

drop policy if exists "Admins can view attendance in their sessions" on public.attendances;
create policy "Admins can view attendance in their sessions" on public.attendances
  for select using (
    exists (
      select 1 from public.attendance_sessions s
      join public.organization_members m on s.organization_id = m.organization_id
      where s.id = attendances.session_id
        and m.user_id = auth.uid()
        and m.role = 'admin'
    )
  );

drop policy if exists "Students can check in to active sessions" on public.attendances;
create policy "Students can check in to active sessions" on public.attendances
  for insert with check (
    student_id = auth.uid() AND
    exists (
      select 1 from public.attendance_sessions
      where id = session_id and is_active = true and expires_at > now()
    )
  );

drop policy if exists "Students can update their own check-out" on public.attendances;
create policy "Students can update their own check-out" on public.attendances
  for update using (student_id = auth.uid());
