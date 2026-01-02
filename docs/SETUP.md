# GitHub Pages Setup Instructions for petscans.app

Follow these steps to deploy your website to GitHub Pages and connect your Namecheap domain.

## Step 1: Push to GitHub

If you haven't already, push your PetScans repository to GitHub:

```bash
cd /Users/lanre/PetScans
git add docs/
git commit -m "Add website for petscans.app"
git push origin main
```

## Step 2: Enable GitHub Pages

1. Go to your GitHub repository: `https://github.com/YOUR_USERNAME/PetScans`
2. Click **Settings** (gear icon)
3. In the left sidebar, click **Pages**
4. Under "Build and deployment":
   - **Source**: Select "Deploy from a branch"
   - **Branch**: Select `main` and `/docs` folder
5. Click **Save**

GitHub will start building your site. It may take a few minutes.

## Step 3: Configure Namecheap DNS

Log in to your Namecheap account and configure DNS for `petscans.app`:

1. Go to **Domain List** → Click **Manage** next to `petscans.app`
2. Click **Advanced DNS** tab
3. Delete any existing A Records or CNAME Records for `@` and `www`
4. Add the following records:

### A Records (for apex domain: petscans.app)

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | @ | 185.199.108.153 | Automatic |
| A Record | @ | 185.199.109.153 | Automatic |
| A Record | @ | 185.199.110.153 | Automatic |
| A Record | @ | 185.199.111.153 | Automatic |

### CNAME Record (for www subdomain)

| Type | Host | Value | TTL |
|------|------|-------|-----|
| CNAME Record | www | YOUR_USERNAME.github.io. | Automatic |

**Note:** Replace `YOUR_USERNAME` with your actual GitHub username.

## Step 4: Verify Custom Domain in GitHub

1. Go back to your GitHub repository **Settings** → **Pages**
2. Under "Custom domain", enter: `petscans.app`
3. Click **Save**
4. GitHub will verify DNS configuration (this may take up to 24 hours)
5. Once verified, check **Enforce HTTPS**

## Step 5: Wait for DNS Propagation

DNS changes can take up to 24-48 hours to propagate worldwide. During this time:
- Your site might be temporarily unavailable
- HTTPS certificate provisioning may fail initially (try again later)

## Verification

Once everything is set up, your website will be available at:
- https://petscans.app (main domain)
- https://www.petscans.app (www subdomain)

## Troubleshooting

### "Domain not properly configured"
- Wait 24 hours for DNS propagation
- Verify all A records are correct
- Ensure CNAME file exists in `/docs` folder

### HTTPS not working
- Wait for DNS verification to complete
- Try unchecking and re-checking "Enforce HTTPS"
- GitHub automatically provisions SSL certificates via Let's Encrypt

### 404 error on pages
- Ensure `index.html` exists in `/docs` folder
- Check that GitHub Pages source is set to `/docs`

## File Structure

```
docs/
├── CNAME                 # Custom domain configuration
├── index.html            # Landing page
├── support.html          # Support page
├── privacy.html          # Privacy Policy
├── terms.html            # Terms of Service
├── css/
│   └── styles.css        # Stylesheet
├── js/
│   └── main.js           # JavaScript
└── images/
    ├── icon.png          # App icon
    └── favicon.png       # Favicon
```

## Updating the Website

To make changes:

1. Edit files in the `/docs` folder
2. Commit and push:
   ```bash
   git add docs/
   git commit -m "Update website"
   git push origin main
   ```
3. GitHub Pages will automatically rebuild (usually within 1-2 minutes)

## Support

If you need help, contact: petscansapp@gmail.com
