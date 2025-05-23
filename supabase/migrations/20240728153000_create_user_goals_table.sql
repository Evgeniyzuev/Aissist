-- Migration: Create goals and user_goals tables
-- Timestamp: 20240728153000

-- Create the GoalStatus enum type
create type goal_status as enum (
  'not_started',  -- Goal is created but not started
  'in_progress',  -- User is actively working on the goal
  'completed',    -- Goal has been achieved
  'paused',       -- Progress temporarily halted
  'abandoned'     -- User has given up on the goal
);

-- Create the goals table (templates)
create table public.goals (
  id bigint generated by default as identity primary key,
  created_at timestamp with time zone not null default now(),
  title text not null,
  description text null,
  image_url text null,
  estimated_cost text null, -- e.g., "$5,000", "10 hours"
  steps jsonb null, -- Array of strings stored as jsonb
  difficulty_level smallint
);

-- Add comments to goals table columns
comment on table public.goals is 'Predefined goal templates that users can choose from';
comment on column public.goals.id is 'Primary Key';
comment on column public.goals.created_at is 'Timestamp when the goal template was created';
comment on column public.goals.title is 'Title of the goal template';
comment on column public.goals.description is 'Detailed description of the goal';
comment on column public.goals.image_url is 'URL for an image representing the goal';
comment on column public.goals.estimated_cost is 'Estimated cost or effort (e.g., "$5,000", "10 hours")';
comment on column public.goals.steps is 'Array of steps or milestones for the goal, stored as JSONB';
comment on column public.goals.difficulty_level is 'Difficulty level of the goal';

-- Create the user_goals table (user instances of goals)
create table public.user_goals (
  id bigint generated by default as identity primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  goal_id bigint not null references public.goals(id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  status goal_status not null default 'not_started',
  started_at timestamp with time zone null,
  target_date date null,
  completed_at timestamp with time zone null,
  progress_percentage smallint null check (progress_percentage >= 0 and progress_percentage <= 100),
  current_step_index integer null,
  progress_details jsonb null,
  notes text null,
  difficulty_level smallint
);

-- Add comments to user_goals table columns
comment on table public.user_goals is 'User-specific instances of goals with progress tracking';
comment on column public.user_goals.id is 'Primary Key';
comment on column public.user_goals.user_id is 'Foreign key to public.users.id';
comment on column public.user_goals.goal_id is 'Foreign key to public.goals.id';
comment on column public.user_goals.created_at is 'Timestamp when the user added this goal';
comment on column public.user_goals.updated_at is 'Timestamp when the user goal was last updated';
comment on column public.user_goals.status is 'Current status of the goal for the user';
comment on column public.user_goals.started_at is 'Timestamp when the user started working on the goal';
comment on column public.user_goals.target_date is 'User-defined target completion date';
comment on column public.user_goals.completed_at is 'Timestamp when the user completed the goal';
comment on column public.user_goals.progress_percentage is 'User-reported progress (0-100)';
comment on column public.user_goals.current_step_index is 'Index of the current step the user is on';
comment on column public.user_goals.progress_details is 'JSONB field for storing detailed progress';
comment on column public.user_goals.notes is 'User notes specific to this goal instance';
comment on column public.user_goals.difficulty_level is 'User-defined or inherited difficulty level';

-- Create indexes for frequently queried columns
create index idx_user_goals_user_id on public.user_goals(user_id);
create index idx_user_goals_goal_id on public.user_goals(goal_id);
create index idx_user_goals_status on public.user_goals(status);
create index idx_goals_difficulty_level on public.goals(difficulty_level);
create index idx_user_goals_difficulty_level on public.user_goals(difficulty_level);

-- Function to automatically update updated_at timestamp
create or replace function handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger to update updated_at on user_goals update
create trigger on_user_goals_update
  before update on public.user_goals
  for each row
  execute function handle_updated_at();

-- Enable Row Level Security (RLS)
alter table public.goals enable row level security;
alter table public.user_goals enable row level security;

-- RLS Policies for goals table
create policy "Allow authenticated read access to goals"
  on public.goals
  for select
  using (auth.role() = 'authenticated');

-- RLS Policies for user_goals table
create policy "Users can view their own goals"
  on public.user_goals
  for select
  using (auth.uid() = user_id);

create policy "Users can insert their own goals"
  on public.user_goals
  for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own goals"
  on public.user_goals
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own goals"
  on public.user_goals
  for delete
  using (auth.uid() = user_id); 