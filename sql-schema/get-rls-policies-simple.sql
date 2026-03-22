-- Simple Query to Get All RLS Policies
-- Run this in Supabase SQL Editor, then copy the results

SELECT 
    '-- ' || tablename || ' - ' || policyname || E'\n' ||
    'CREATE POLICY "' || policyname || '" ON ' || tablename || E'\n' ||
    '    FOR ' || 
    CASE 
        WHEN cmd = 'SELECT' THEN 'SELECT'
        WHEN cmd = 'INSERT' THEN 'INSERT'
        WHEN cmd = 'UPDATE' THEN 'UPDATE'
        WHEN cmd = 'DELETE' THEN 'DELETE'
        WHEN cmd = 'ALL' THEN 'ALL'
        ELSE cmd::text
    END || E'\n' ||
    CASE 
        WHEN qual IS NOT NULL THEN '    USING (' || qual || ')' || E'\n'
        ELSE ''
    END ||
    CASE 
        WHEN with_check IS NOT NULL THEN '    WITH CHECK (' || with_check || ');'
        ELSE ';'
    END || E'\n' AS policy_statement
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, 
    CASE cmd
        WHEN 'SELECT' THEN 1
        WHEN 'INSERT' THEN 2
        WHEN 'UPDATE' THEN 3
        WHEN 'DELETE' THEN 4
        WHEN 'ALL' THEN 5
        ELSE 6
    END,
    policyname;

