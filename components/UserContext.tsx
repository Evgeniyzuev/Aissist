"use client";

import React, { createContext, useContext, useEffect, useState, ReactNode } from "react";
import WebApp from '@twa-dev/sdk';
import { createClient } from '@supabase/supabase-js';

// Типы данных
interface TelegramUser {
  id: number;
  first_name?: string;
  last_name?: string;
  username?: string;
  photo_url?: string;
}

interface DbUser {
  id: string;
  user_id: string;
  telegram_id: number;
  telegram_username?: string;
  first_name?: string;
  last_name?: string;
  avatar_url?: string;
  phone_number?: string;
  created_at: string;
  // Добавьте другие поля из вашей таблицы users
}

interface UserContextType {
  telegramUser: TelegramUser | null;
  dbUser: DbUser | null;
  isLoading: boolean;
  error: string | null;
  refreshUserData: () => Promise<void>;
}

const UserContext = createContext<UserContextType | undefined>(undefined);

// Инициализируем Supabase клиент
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const supabase = createClient(supabaseUrl, supabaseAnonKey);

export const UserProvider = ({ children }: { children: ReactNode }) => {
  const [telegramUser, setTelegramUser] = useState<TelegramUser | null>(null);
  const [dbUser, setDbUser] = useState<DbUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Функция для обновления данных пользователя из БД
  const refreshUserData = async () => {
    if (!telegramUser?.id) return;
    
    try {
      const { data, error: fetchError } = await supabase
        .from('users')
        .select('*')
        .eq('telegram_id', telegramUser.id)
        .single();

      if (fetchError && fetchError.code !== 'PGRST116') {  // PGRST116 = 'не найдено'
        console.error('Error fetching user data:', fetchError);
        setError('Ошибка при получении данных пользователя');
      } else {
        setDbUser(data);
      }
    } catch (err) {
      console.error('Error refreshing user data:', err);
      setError('Ошибка при обновлении данных пользователя');
    }
  };

  useEffect(() => {
    // Функция для инициализации данных пользователя из Telegram и проверки/создания в БД
    const initUser = async () => {
      setIsLoading(true);
      setError(null);
      
      try {
        // Проверяем, запущены ли мы в Telegram
        let isTelegram = false;
        let userData: TelegramUser | null = null;
        
        try {
          WebApp.ready();
          const initData = WebApp.initDataUnsafe;
          
          if (initData?.user) {
            isTelegram = true;
            userData = initData.user;
            console.log('Telegram user data:', userData);
            setTelegramUser(userData);
          }
        } catch (e) {
          console.log('Not running inside Telegram or WebApp not available');
        }

        // Если мы получили данные пользователя из Telegram
        if (isTelegram && userData?.id) {
          // Отправляем данные на API для верификации и сохранения
          const response = await fetch('/api/auth/telegram-user', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              telegramUser: userData,
              initData: WebApp.initData,  // Для верификации на сервере
            }),
          });

          const result = await response.json();
          
          if (!response.ok) {
            throw new Error(result.error || 'Ошибка при сохранении данных пользователя');
          }
          
          if (result.user) {
            setDbUser(result.user);
          } else {
            await refreshUserData();  // Пробуем загрузить из БД если API не вернул пользователя
          }
        }
      } catch (e: any) {
        console.error('Error initializing user:', e);
        setError(e.message || 'Ошибка при инициализации пользователя');
      } finally {
        setIsLoading(false);
      }
    };

    initUser();
  }, []);

  const value = {
    telegramUser,
    dbUser,
    isLoading,
    error,
    refreshUserData,
  };

  return <UserContext.Provider value={value}>{children}</UserContext.Provider>;
};

// Hook для использования контекста в компонентах
export const useUser = () => {
  const context = useContext(UserContext);
  if (context === undefined) {
    throw new Error('useUser must be used within a UserProvider');
  }
  return context;
}; 