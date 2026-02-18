# How to Publish Flit

Follow these steps in order. Each step is done once. At the end, anyone on macOS can install your app with a single command.

---

## Step 1 — Find your Apple Team ID

1. Go to [developer.apple.com](https://developer.apple.com) and sign in
2. Click **Account** in the top menu
3. Your **Team ID** is the 10-character code shown on the right side (looks like `AB12CD34EF`)
4. Copy it somewhere — you'll paste it a few times below

---

## Step 2 — Create a signing certificate in Xcode

This is the certificate that tells macOS "this app is safe to run."

1. Open Xcode → in the top menu go to **Xcode → Settings → Accounts**
2. Select your Apple ID on the left, then click **Manage Certificates** on the right
3. Click the **+** button at the bottom left → choose **Developer ID Application**
4. Xcode creates and saves the certificate automatically. Done.

Verify it worked — run this in Terminal:
```bash
security find-identity -v -p codesigning | grep "Developer ID"
```
You should see one line with your name in it.

---

## Step 3 — Export the certificate for GitHub

GitHub needs a copy of your certificate to sign the app in the cloud.

> **Why you couldn't export as .p12 before:** Keychain Access has multiple categories in the left sidebar. If you were in "Certificates" you can only export `.cer` files (the certificate alone, without its private key). The `.p12` format bundles both the certificate *and* its private key together, and is only available when you export from the **My Certificates** category.

1. Open **Keychain Access** (search for it in Spotlight)
2. In the **left sidebar**, look for the category list — click **My Certificates** (not "Certificates")
3. You will see an entry called `Developer ID Application: Your Name (TEAMID)` with a small triangle next to it. That triangle means the private key is attached. This is the one you need.
4. Right-click that entry → **Export "Developer ID Application: …"**
5. In the save dialog, make sure the format says **Personal Information Exchange (.p12)** — it should automatically show this option now
6. Save it to your Desktop as `DevIDCert.p12`
7. It will ask for a password — make one up and **write it down**, you'll need it in Step 7

Now convert the file to text so you can paste it into GitHub:
```bash
base64 -i ~/Desktop/DevIDCert.p12 | pbcopy
```
This copies the encoded certificate to your clipboard. Paste it into a notes app for now — this is your `CERT_P12` value.

> **If you still don't see the .p12 option:** it means Keychain doesn't have the private key for that certificate on this Mac. This happens if the certificate was created on a different machine. In that case, go back to Step 2 — delete the existing certificate in Xcode's Manage Certificates screen and recreate it. Xcode will generate a fresh certificate with the private key stored locally, and you'll be able to export it as .p12.

---

## Step 4 — Create an app-specific password

Apple won't let automated tools use your real password, so you create a separate one just for this.

1. Go to [appleid.apple.com](https://appleid.apple.com) and sign in
2. Click **Sign-In and Security** → **App-Specific Passwords**
3. Click the **+** icon → name it `Flit Notarization` → click **Create**
4. Copy the password it shows you (format: `xxxx-xxxx-xxxx-xxxx`) — this is your `APP_PASSWORD`

---

## Step 5 — Create two GitHub repositories

You need two public repositories:

**Repository 1 — the app itself:**
1. Go to [github.com/new](https://github.com/new)
2. Name it `Flit` (must be exactly this to match the workflow file)
3. Set it to **Public**, leave everything else as default, click **Create repository**
4. Then in Terminal, from the `tile-manager` folder:
```bash
git remote add origin https://github.com/alimuratkuslu/Flit.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

> The `git add .` and `git commit` are required before pushing — Git cannot push a branch that has no commits yet.

**Repository 2 — the Homebrew tap** (this is how people install via `brew`):
1. Go to [github.com/new](https://github.com/new) again
2. Name it exactly `homebrew-flit` — this name is required by Homebrew
3. Set it to **Public**, click **Create repository**
4. Then in Terminal:
```bash
cd ~/Desktop
mkdir homebrew-flit-publish && cd homebrew-flit-publish
git init -b main
git remote add origin https://github.com/alimuratkuslu/homebrew-flit.git
mkdir Casks
cp ~/Desktop/tile-manager/homebrew-flit/Casks/flit.rb Casks/
git add .
git commit -m "Add flit cask"
git push -u origin main
```

---

## Step 6 — Create a GitHub access token for the tap

After each release, GitHub Actions automatically updates the Homebrew tap. For that it needs permission to write to the `homebrew-flit` repo.

1. Go to GitHub → click your profile photo top-right → **Settings**
2. Scroll all the way down the left sidebar → **Developer settings**
3. Click **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
4. Fill in:
   - **Token name:** `Flit tap writer`
   - **Repository access:** select *Only selected repositories* → pick `homebrew-flit`
   - Under **Permissions** → **Repository permissions** → **Contents** → set to **Read and write**
5. Click **Generate token** → copy the token that appears — this is your `TAP_REPO_TOKEN`

---

## Step 7 — Add all secrets to GitHub Actions

Go to `github.com/alimuratkuslu/Flit` → **Settings** → **Secrets and variables** → **Actions** → click **New repository secret** for each one below:

| Name | What to paste |
|---|---|
| `CERT_P12` | The long text you copied in Step 3 (the base64 certificate) |
| `CERT_PASSWORD` | The password you made up when exporting the .p12 in Step 3 |
| `APPLE_ID` | Your Apple ID email address |
| `APP_PASSWORD` | The `xxxx-xxxx-xxxx-xxxx` password from Step 4 |
| `TEAM_ID` | Your 10-character Team ID from Step 1 |
| `TAP_REPO_TOKEN` | The token from Step 6 |

---

## Step 8 — Put your Team ID in the project

Open Terminal in the `tile-manager` folder and run:
```bash
/usr/libexec/PlistBuddy -c "Set :teamID YOUR_TEAM_ID" ExportOptions.plist
```
Replace `YOUR_TEAM_ID` with the actual ID from Step 1, for example:
```bash
/usr/libexec/PlistBuddy -c "Set :teamID AB12CD34EF" ExportOptions.plist
```

Then commit and push that change:
```bash
git add ExportOptions.plist
git commit -m "Set Team ID"
git push
```

---

## Step 9 — Publish your first release

This one command does everything — GitHub Actions will build, sign, notarize, and publish the app automatically:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Then go to `github.com/alimuratkuslu/Flit` → click the **Actions** tab → you'll see a workflow running. It takes about 10–15 minutes. When it turns green, your app is live.

---

## Step 10 — Install and test it

Once the workflow finishes, test it works:

```bash
brew tap alimuratkuslu/flit
brew install --cask flit
```

Flit should appear in your Applications folder and run normally. Anyone on macOS can now use those same two commands to install your app.

---

## How to release a future update

When you make changes and want to publish a new version:

1. Open `Flit/Info.plist` in Xcode and increase the version number (e.g. `1.0.0` → `1.1.0`)
2. Commit your changes:
```bash
git add .
git commit -m "Version 1.1.0"
```
3. Tag and push:
```bash
git tag v1.1.0
git push origin main --tags
```

GitHub Actions handles the rest automatically.
