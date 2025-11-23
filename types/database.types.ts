// Database types for Supabase
// This file is required by @nuxtjs/supabase module
// You can generate types using: npx supabase gen types typescript --project-id <your-project-id>

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      // Add your table types here if needed
      // Example:
      // employees: {
      //   Row: {
      //     id: string
      //     first_name: string
      //     // ... other fields
      //   }
      //   Insert: {
      //     id?: string
      //     first_name: string
      //     // ... other fields
      //   }
      //   Update: {
      //     id?: string
      //     first_name?: string
      //     // ... other fields
      //   }
      // }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

