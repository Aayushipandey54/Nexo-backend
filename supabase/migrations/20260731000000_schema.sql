-- 1. ENABLE UUID EXTENSION
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. EVENT STATE TABLE (Single Row Engine Control)
CREATE TABLE IF NOT EXISTS public.event_state (
    id INT PRIMARY KEY DEFAULT 1,
    current_mission TEXT NOT NULL DEFAULT 'MISSION_1', -- 'MISSION_1' | 'MISSION_2' | 'MISSION_3' | 'TOURNAMENT COMPLETE'
    current_stage TEXT NOT NULL DEFAULT 'WAITING', -- 'WAITING' | 'LIVE' | 'EVALUATION' | 'RESULTS' | 'VICTORY'
    event_status TEXT NOT NULL DEFAULT 'ONLINE', -- 'ONLINE' | 'PAUSED' | 'ENDED'
    publish_m1_results BOOLEAN NOT NULL DEFAULT FALSE,
    publish_m2_results BOOLEAN NOT NULL DEFAULT FALSE,
    publish_winners BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = 1)
);

-- Seed initial event state row
INSERT INTO public.event_state (id, current_mission, current_stage, event_status)
VALUES (1, 'MISSION_1', 'WAITING', 'ONLINE')
ON CONFLICT (id) DO NOTHING;

-- Enable Realtime for event_state safely
DO $$ 
BEGIN 
    ALTER PUBLICATION supabase_realtime ADD TABLE public.event_state;
EXCEPTION 
    WHEN duplicate_object THEN NULL;
END $$;

-- 3. TEAMS & ACCESS KEYS TABLE
CREATE TABLE IF NOT EXISTS public.teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_name TEXT NOT NULL,
    access_key TEXT UNIQUE NOT NULL,
    current_mission TEXT DEFAULT 'Mission 1',
    current_screen TEXT DEFAULT 'Login',
    status TEXT DEFAULT 'Online',
    total_score INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed initial event access keys
INSERT INTO public.teams (team_name, access_key, total_score) VALUES
('Quantum Core', 'NXR-A71F', 1200),
('Byte Hunters', 'NXR-B92E', 950),
('Vortex Neural', 'NXR-C34D', 1850),
('CESA Titans', 'NXR-D56C', 2400)
ON CONFLICT (access_key) DO NOTHING;

-- Enable Realtime for teams safely
DO $$ 
BEGIN 
    ALTER PUBLICATION supabase_realtime ADD TABLE public.teams;
EXCEPTION 
    WHEN duplicate_object THEN NULL;
END $$;

-- 4. MISSION 1: MCQ QUESTIONS TABLE
CREATE TABLE IF NOT EXISTS public.mcq_questions (
    id SERIAL PRIMARY KEY,
    category TEXT NOT NULL,
    question TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_index INT NOT NULL,
    explanation TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed initial MCQ questions
INSERT INTO public.mcq_questions (category, question, options, correct_index, explanation) VALUES
('Programming', 'In JavaScript V8 engine, which heap memory optimization prevents garbage collection spikes for short-lived objects?', '["Generational Garbage Collection (Scavenger)", "Mark-Sweep-Compact exclusively", "Reference Counting with zero overhead", "Static allocation without heap"]', 0, 'V8 uses a Generational GC with a Young Generation (Scavenger) for short-lived objects.'),
('Networking', 'Which TCP flag combo initiates the standard 3-way handshake before encrypted data transmission?', '["FIN, ACK", "SYN, SYN-ACK, ACK", "RST, PSH", "URG, ECE"]', 1, 'SYN -> SYN-ACK -> ACK establishes a TCP session handshake.'),
('Operating Systems', 'What occurs when a process attempts to access a virtual memory address that is not currently mapped into physical RAM?', '["Kernel Panic", "Page Fault Interrupt", "Segmentation Fault Error", "Thread Deadlock"]', 1, 'The CPU triggers a Page Fault interrupt, allowing the OS kernel to load the required page from swap.'),
('Databases', 'In ACID transaction properties, which property guarantees that executed changes persist even during power outage?', '["Atomicity", "Consistency", "Isolation", "Durability"]', 3, 'Durability ensures committed records are saved to non-volatile storage.'),
('AI', 'Which neural network architecture introduced self-attention mechanisms to revolutionize Transformer models?', '["Vaswani et al. (Attention Is All You Need)", "LeCun Convolutional Networks", "Hopfield Recurrent Networks", "Markov Decision Chains"]', 0, 'The 2017 Transformer paper "Attention Is All You Need" introduced self-attention mechanisms.'),
('Security', 'What type of cryptographic attack pre-computes hashes of common passwords to match stolen password hashes rapidly?', '["Rainbow Table Attack", "Man-In-The-Middle Attack", "Cross-Site Scripting (XSS)", "Buffer Overflow Attack"]', 0, 'Rainbow tables use pre-computed hash chains to reverse cryptographic hash functions quickly.'),
('CS Core', 'What is the worst-case time complexity of standard QuickSort algorithm when a bad pivot is selected?', '["O(N log N)", "O(N^2)", "O(N)", "O(2^N)"]', 1, 'When the smallest or largest element is consistently picked as the pivot, QuickSort degenerates to O(N^2).'),
('Programming', 'What is a Closure in functional programming & JavaScript paradigm?', '["A function bundled together with references to its surrounding lexical environment", "A method that closes a database socket connection", "A private class constructor", "A memory leak prevention routine"]', 0, 'A closure gives an inner function access to an outer function scope variables even after execution finishes.'),
('Networking', 'Which OSI layer handles end-to-end flow control, segment retransmission, and port addressing (e.g. TCP/UDP)?', '["Layer 3 - Network", "Layer 4 - Transport", "Layer 2 - Data Link", "Layer 7 - Application"]', 1, 'The Transport Layer (Layer 4) handles end-to-end communication, ports, and segmentation.'),
('Operating Systems', 'What condition causes two or more processes to be blocked forever, each waiting for a resource held by the other?', '["Starvation", "Deadlock", "Race Condition", "Context Switch Overhead"]', 1, 'Deadlock occurs when mutual exclusion, hold and wait, no preemption, and circular wait are satisfied.'),
('Databases', 'In relational dependencies, which Normal Form eliminates transitive functional dependencies?', '["First Normal Form (1NF)", "Second Normal Form (2NF)", "Third Normal Form (3NF)", "Boyce-Codd Normal Form (BCNF)"]', 2, '3NF requires that every non-prime attribute is non-transitively dependent on every candidate key.'),
('CS Core', 'Which graph traversal algorithm guarantees finding the shortest path in an unweighted graph?', '["Breadth-First Search (BFS)", "Depth-First Search (DFS)", "Pre-order Binary Tree Traversal", "Kruskal Algorithm"]', 0, 'BFS explores nodes level by level, ensuring the shortest path in unweighted graphs.'),
('Programming', 'In object-oriented design, what does the "L" in SOLID design principles stand for?', '["Liskov Substitution Principle", "Linear Inheritance Pattern", "Loop Decoupling Architecture", "Log Abstraction Layer"]', 0, 'Liskov Substitution Principle specifies that objects of a superclass should be replaceable with objects of a subclass.'),
('Security', 'Which HTTP security header mitigates Cross-Site Scripting (XSS) by restricting sources of executable scripts?', '["Content-Security-Policy (CSP)", "X-Frame-Options", "Access-Control-Allow-Origin", "Strict-Transport-Security (HSTS)"]', 0, 'CSP headers restrict the resources (such as JavaScript, CSS, Images) that the browser is allowed to load.'),
('AI', 'In Machine Learning, what technique helps prevent model Overfitting by penalizing large parameter weights?', '["Regularization (L1 / L2 Weight Decay)", "Data Imputation", "One-Hot Encoding", "Gradient Vanishing"]', 0, 'Regularization techniques like L1 (Lasso) and L2 (Ridge) penalize large weights to prevent overfitting.')
ON CONFLICT DO NOTHING;

-- 5. MISSION 2: WORDLE TARGETS TABLE
CREATE TABLE IF NOT EXISTS public.wordle_words (
    id SERIAL PRIMARY KEY,
    word VARCHAR(5) UNIQUE NOT NULL,
    hint TEXT NOT NULL,
    category TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed initial Wordle targets
INSERT INTO public.wordle_words (word, hint, category) VALUES
('ARRAY', 'Sequential data structure in memory', 'Data Structures'),
('STACK', 'LIFO evaluation structure for functions', 'Algorithms'),
('CACHE', 'High speed temporary hardware buffer', 'Architecture')
ON CONFLICT (word) DO NOTHING;

-- 6. MISSION SUBMISSIONS TABLE (Mission 1, 2, and 3 GitHub Repo Links)
CREATE TABLE IF NOT EXISTS public.submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
    team_name TEXT NOT NULL,
    mission INT NOT NULL,
    repo_url TEXT,
    score INT DEFAULT 0,
    status TEXT DEFAULT 'PENDING', -- 'VERIFIED' | 'PENDING' | 'REJECTED'
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Realtime for submissions table safely
DO $$ 
BEGIN 
    ALTER PUBLICATION supabase_realtime ADD TABLE public.submissions;
EXCEPTION 
    WHEN duplicate_object THEN NULL;
END $$;

-- 7. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.event_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mcq_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wordle_words ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

-- Allow public read access
DROP POLICY IF EXISTS "Public Read Event State" ON public.event_state;
CREATE POLICY "Public Read Event State" ON public.event_state FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public Read Questions" ON public.mcq_questions;
CREATE POLICY "Public Read Questions" ON public.mcq_questions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public Read Wordle Words" ON public.wordle_words;
CREATE POLICY "Public Read Wordle Words" ON public.wordle_words FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public Read Teams" ON public.teams;
CREATE POLICY "Public Read Teams" ON public.teams FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public Read Submissions" ON public.submissions;
CREATE POLICY "Public Read Submissions" ON public.submissions FOR SELECT USING (true);

-- Allow public insert/update/manage
DROP POLICY IF EXISTS "Public Insert Submissions" ON public.submissions;
CREATE POLICY "Public Insert Submissions" ON public.submissions FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public Update Submissions" ON public.submissions;
CREATE POLICY "Public Update Submissions" ON public.submissions FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Public Manage Questions" ON public.mcq_questions;
CREATE POLICY "Public Manage Questions" ON public.mcq_questions FOR ALL USING (true);

DROP POLICY IF EXISTS "Public Manage Wordle" ON public.wordle_words;
CREATE POLICY "Public Manage Wordle" ON public.wordle_words FOR ALL USING (true);

DROP POLICY IF EXISTS "Public Manage Event State" ON public.event_state;
CREATE POLICY "Public Manage Event State" ON public.event_state FOR ALL USING (true);

DROP POLICY IF EXISTS "Public Manage Teams" ON public.teams;
CREATE POLICY "Public Manage Teams" ON public.teams FOR ALL USING (true);
