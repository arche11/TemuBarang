# TRACE — Lost & Found (Vercel + Supabase)

This edition adds real authentication and server-side roles:
- user: submit reports, save reports, manage own profile
- moderator: review submissions and update report status
- admin: all moderator permissions plus change member roles

## 1. Create the Supabase backend
1. Create a project at https://supabase.com.
2. Open SQL Editor > New query.
3. Paste and run all contents of `schema.sql`.
4. In Authentication > Providers > Email, enable Email provider.
5. For quick testing, you may turn off email confirmation. For a public launch, keep confirmation enabled and configure SMTP.
6. In Project Settings > API, copy Project URL and anon/public key.

## 2. Connect the frontend
1. Copy `config.example.js` and rename the copy to `config.js`.
2. Replace `PASTE_YOUR_SUPABASE_PROJECT_URL` and `PASTE_YOUR_SUPABASE_ANON_KEY`.
3. Do not put the `service_role` key in frontend code. Only use the anon/public key.
4. Test locally using VS Code Live Server. Do not open as `file://` if auth callbacks behave unexpectedly.

## 3. Make your first account an admin
1. Register your own account in TRACE.
2. In Supabase > SQL Editor, run:
   `update public.profiles set role = 'admin' where email = 'YOUR_EMAIL@example.com';`
3. Sign out and sign back in. The Admin panel will appear.
4. Admin can promote other users to moderator/admin from Admin panel.

## 4. Deploy to Vercel
1. Push `index.html`, `style.css`, `script.js`, `config.js`, `vercel.json` to a GitHub repository.
2. Import the repository at https://vercel.com/new.
3. Framework Preset: Other.
4. Build Command: leave empty.
5. Output Directory: `.`.
6. Deploy.

## How TRACE works
1. A visitor can browse public reports that staff have approved.
2. To report an item or save one, the visitor registers/signs in.
3. A new report is saved in Supabase with status `pending`.
4. Admin/moderator opens Admin panel and approves/rejects it or marks it returned.
5. Only approved/returned reports show publicly.
6. Admin can change user roles. The role is stored in the database and checked by Supabase Row Level Security (RLS), not just hidden UI buttons.

## Important notes
- Vercel hosts the static frontend. Supabase provides authentication and PostgreSQL database.
- This edition does not use PHP. PHP is not natively executed by Vercel. If you specifically need PHP, deploy a PHP backend to a PHP-capable host and connect the frontend to it.
- Report image upload is not included in this backend edition yet. The database has an optional `image_url` field for a later Supabase Storage integration.
- Contact details are not exposed publicly in this starter build. Add a safe contact workflow before real public use.
- Never expose Supabase `service_role` key in browser code.


Website ini telah disesuaikan menjadi TemuBarang, platform Lost & Found SMP Negeri 2 Ciomas dengan antarmuka Bahasa Indonesia dan tema biru.
