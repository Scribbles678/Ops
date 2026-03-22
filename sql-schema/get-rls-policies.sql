-- SQL Queries to Extract All RLS Policies
-- Run these queries in Supabase SQL Editor to get all your RLS policies

-- ============================================
-- Option 1: Get All Policy Details (Recommended)
-- ============================================
-- This shows all policies with their details in a readable format

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd AS command,  -- SELECT, INSERT, UPDATE, DELETE, or ALL
    qual AS using_expression,
    with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================
-- Option 2: Generate CREATE POLICY Statements
-- ============================================
-- This attempts to reconstruct CREATE POLICY statements
-- Note: May need manual adjustment for complex policies

SELECT 
    'CREATE POLICY "' || policyname || '" ON ' || schemaname || '.' || tablename || E'\n' ||
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
    END AS create_policy_statement
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================
-- Option 3: Get Policies by Table (Organized)
-- ============================================
-- Shows policies grouped by table

SELECT 
    tablename,
    policyname,
    cmd AS command,
    CASE 
        WHEN qual IS NOT NULL THEN 'USING (' || qual || ')'
        ELSE 'USING (true)'
    END AS using_clause,
    CASE 
        WHEN with_check IS NOT NULL THEN 'WITH CHECK (' || with_check || ')'
        ELSE ''
    END AS with_check_clause
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

-- ============================================
-- Option 4: Check Which Tables Have RLS Enabled
-- ============================================

SELECT 
    schemaname,
    tablename,
    rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================
-- Option 5: Get Full Policy Information (Most Complete)
-- ============================================
-- This gives you everything you need to document policies

SELECT 
    p.schemaname,
    p.tablename,
    p.policyname,
    p.permissive,
    p.roles,
    p.cmd AS command,
    p.qual AS using_expression,
    p.with_check AS with_check_expression,
    CASE 
        WHEN t.rowsecurity THEN 'RLS Enabled'
        ELSE 'RLS Disabled'
    END AS rls_status
FROM pg_policies p
LEFT JOIN pg_tables t ON p.schemaname = t.schemaname AND p.tablename = t.tablename
WHERE p.schemaname = 'public'
ORDER BY p.tablename, 
    CASE p.cmd
        WHEN 'SELECT' THEN 1
        WHEN 'INSERT' THEN 2
        WHEN 'UPDATE' THEN 3
        WHEN 'DELETE' THEN 4
        WHEN 'ALL' THEN 5
        ELSE 6
    END,
    p.policyname;

