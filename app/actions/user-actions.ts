"use server"

import { createServerSupabaseClient } from "@/lib/supabase"

export interface UserData {
  id: string
  telegram_id: number
  telegram_username?: string | null
  first_name?: string | null
  last_name?: string | null
  reinvest: number
  aicore_balance: number
  wallet_balance: number
  level: number
  paid_referrals: number
  referrer_id?: number | null
}

export async function getUsers() {
  try {
    const supabase = createServerSupabaseClient()

    const { data, error } = await supabase.from("users").select("*")

    if (error) {
      console.error("Error fetching users:", error)
      return { success: false, error: error.message, users: [] }
    }

    return { success: true, users: data as UserData[] }
  } catch (error) {
    console.error("Error in getUsers:", error)
    return { success: false, error: "Failed to fetch users", users: [] }
  }
}

export async function getCurrentUser() {
  try {
    const supabase = createServerSupabaseClient()

    // For demo purposes, we'll just get the first user
    // In a real app, you would get the authenticated user
    const { data, error } = await supabase.from("users").select("*").limit(1).single()

    if (error) {
      console.error("Error fetching current user:", error)
      return { success: false, error: error.message, user: null }
    }

    return { success: true, user: data as UserData }
  } catch (error) {
    console.error("Error in getCurrentUser:", error)
    return { success: false, error: "Failed to fetch current user", user: null }
  }
}

