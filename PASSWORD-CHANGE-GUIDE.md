# Password Change Guide

## Method 1: Environment Variable (Recommended)

1. Create a `.env` file in the project root:
```bash
# Add this line to your .env file
APP_PASSWORD=your_new_password_here
```

2. Restart the development server:
```bash
npm run dev
```

## Method 2: Direct Code Change

1. Open `pages/login.vue`
2. Find this line:
```javascript
const CORRECT_PASSWORD = config.public.appPassword || 'operations2024'
```
3. Change `'operations2024'` to your new password:
```javascript
const CORRECT_PASSWORD = config.public.appPassword || 'your_new_password_here'
```

## Method 3: Production Deployment

For production (Netlify, Vercel, etc.), set the environment variable:
- **Netlify**: Site Settings → Environment Variables → Add `APP_PASSWORD`
- **Vercel**: Project Settings → Environment Variables → Add `APP_PASSWORD`

## Security Notes

- Use a strong password (12+ characters, mixed case, numbers, symbols)
- Never commit passwords to version control
- Consider using a password manager to generate secure passwords
- For multiple organizations, consider implementing user management

## Current Default Password
- Default: `operations2024`
- Change this immediately for production use!
