# GitHub Pages Setup Guide

## Privacy Policy Hosted on GitHub Pages

Your privacy policy is now ready to be published on GitHub Pages!

### Files Created:

- `docs/index.html` - Your privacy policy page
- `docs/_config.yml` - GitHub Pages configuration

### How to Enable GitHub Pages:

1. **Push these files to your GitHub repository:**

      ```bash
      git add docs/
      git commit -m "Add privacy policy for GitHub Pages"
      git push origin main
      ```

2. **Enable GitHub Pages in your repository settings:**
      - Go to your repository on GitHub
      - Click on **Settings** (top menu)
      - Scroll down to **Pages** (left sidebar under "Code and automation")
      - Under **Source**, select **Deploy from a branch**
      - Under **Branch**, select:
           - Branch: `main` (or `master`)
           - Folder: `/docs`
      - Click **Save**

3. **Access your privacy policy:**
      - After a few minutes, your privacy policy will be available at:
      - `https://<your-username>.github.io/<repository-name>/`
      - Example: `https://gitcrafter.github.io/Developer-Community-App/`

### Custom Domain (Optional):

If you want to use a custom domain like `privacy.yourdomain.com`:

1. Add a `CNAME` file in the `docs/` folder with your domain
2. Configure your DNS settings with your domain provider
3. Update the custom domain in GitHub Pages settings

### Updating the Privacy Policy:

Simply edit `docs/index.html` and push the changes. GitHub Pages will automatically update within a few minutes.

### Note:

- Make sure your repository is **public** for GitHub Pages to work (or have GitHub Pro/Enterprise for private repos)
- The first deployment may take 5-10 minutes
- You'll receive an email when the site is published

---

**Need help?** Check the [GitHub Pages documentation](https://docs.github.com/en/pages)
