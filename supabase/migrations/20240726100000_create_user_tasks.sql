-- Migration: Create user_tasks table (v2 - removed timestamps, uses tasks.number)
-- Timestamp: Set this to the current timestamp when creating the file

-- 1. Create ENUM type for task statuses
CREATE TYPE task_status AS ENUM (
  'assigned',       -- Task assigned to user
  'in_progress',    -- User started working on the task
  'completed',      -- Task successfully completed
  'failed',         -- Task completion failed
  'pending_review', -- Task completed, awaiting verification
  'archived'        -- Task is no longer relevant or hidden
);

-- 2. Create user_tasks table
CREATE TABLE public.user_tasks (
  id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  -- Ensure this references the correct user identifier (pablic.users.id or profiles.id/user_id)
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  -- IMPORTANT: Ensure tasks.number is UNIQUE or PRIMARY KEY in the tasks table
  task_id bigint NOT NULL REFERENCES public.tasks(number) ON DELETE RESTRICT,
  status task_status NOT NULL DEFAULT 'assigned',
  assigned_at timestamp with time zone DEFAULT now() NOT NULL,
  current_step_index integer DEFAULT 0, -- 0-based index corresponding to tasks.steps_definition
  progress_details jsonb, -- Store specific progress data, e.g., { "step_0_completed": true, "input_value": "xyz" }
  notes text -- User or system notes regarding this specific task instance
);

-- 3. Add comments for clarity
COMMENT ON TABLE public.user_tasks IS 'Tracks the status and progress of tasks assigned to specific users.';
COMMENT ON COLUMN public.user_tasks.user_id IS 'References the user this task status belongs to.';
COMMENT ON COLUMN public.user_tasks.task_id IS 'References the specific task definition using tasks.number.';
COMMENT ON COLUMN public.user_tasks.status IS 'Current completion status of the task for the user.';
COMMENT ON COLUMN public.user_tasks.current_step_index IS '0-based index of the current step the user is working on.';
COMMENT ON COLUMN public.user_tasks.progress_details IS 'JSON blob for storing arbitrary progress data related to the task steps.';

-- 4. Create indexes for performance
CREATE INDEX user_tasks_user_id_idx ON public.user_tasks (user_id);
CREATE INDEX user_tasks_task_id_idx ON public.user_tasks (task_id);
CREATE INDEX user_tasks_status_idx ON public.user_tasks (status);

-- Optional: Add a unique constraint if a user should only have one instance of a specific task
-- Ensure tasks.number is UNIQUE or PRIMARY KEY in tasks table
CREATE UNIQUE INDEX user_tasks_user_id_task_number_key ON public.user_tasks (user_id, task_id);

-- 5. Function and trigger for updated_at are REMOVED

-- 6. Enable Row Level Security (RLS)
ALTER TABLE public.user_tasks ENABLE ROW LEVEL SECURITY;

-- 7. Define RLS Policies (adjust based on your application logic)

-- Policy: Users can view their own task statuses
CREATE POLICY "Allow users to view their own tasks" ON public.user_tasks
  FOR SELECT USING (pablic.uid() = user_id);

-- Policy: Users can update the status, progress, and notes of their own tasks
-- (Restrict status changes if needed, e.g., prevent changing from 'completed')
CREATE POLICY "Allow users to update their own tasks" ON public.user_tasks
  FOR UPDATE USING (pablic.uid() = user_id)
  WITH CHECK (pablic.uid() = user_id);

-- Policy: Allow backend/service role to perform all actions (if needed)
-- CREATE POLICY "Allow full access for service role" ON public.user_tasks
--  FOR ALL USING (pablic.role() = 'service_role');

-- Note: INSERT policy might be restricted to backend logic or specific triggers
-- depending on how tasks are assigned.
-- Example: Allow users to insert if they assign tasks themselves (less common)
-- CREATE POLICY "Allow users to insert their own tasks" ON public.user_tasks
--  FOR INSERT WITH CHECK (pablic.uid() = user_id); 