---
title: "Getting Started"
order: 0
---

# Tourney Balance Open Beta
This site documents how to setup the repository and start contributing to the Tourney Balance mod (official & open beta).

## What is TB Open Beta

Tourney Balance (Open Beta) is a fork from the official Tourney Balance mod. This repository is used for public testing of new features before they get merged into the official mod. If you would like to contribute to Tourney Balance, you can create a pull request on the [Tourney-Balance-Open-Beta](https://github.com/vt2-tourney-balance/Tourney-Balance-Open-Beta) fork.

| Links     | GitHub | Steam Workshop |
|-----------|--------|----------------|
| official  | [link](https://github.com/Camilo-Guzman/Tourney-Balance) | [link](https://steamcommunity.com/sharedfiles/filedetails/?id=2545022878) |
| open beta | [link](https://github.com/vt2-tourney-balance/Tourney-Balance-Open-Beta) | [link](https://steamcommunity.com/sharedfiles/filedetails/?id=3722716715) |

## Contributor Workflow
To allow multiple contributors updating the mod on the Steam Workshop, we have set up this custom workflow
1. Clone the repository
2. Add your changes
3. Build mod locally
4. Push changes to GitHub
5. GitHub Actions handles the upload to Steam Workshop

### Initial Setup
When building the official and open beta mod, having to rename folderscan lead to user errors. We use custom build scripts to simplify this process. Follow the setup below 
1. Setup modding environment with these [instructions](https://vmf-docs.verminti.de/#/).
2. Clone the repository under `\vermintide-mod-builder\mods`.
```
git clone https://github.com/vt2-tourney-balance/Tourney-Balance-Open-Beta.git
```
3. **DON'T** rename the cloned repository.
4. Rename or remove any folder named `TourneyBalance` under `\vermintide-mod-builder\mods`.
5. **COPY** the `.bat` scripts from the cloned repository to `\vermintide-mod-builder`.

### Building the Mod
**DO NOT** use `_Build Mod.bat` to build this mod.
- **To Build the Mod** run these custom build scripts. *This will replace the local copy of your mod, allowing you to test without uploading to Steam.*
    - `_Build TB All.bat` builds both the Official and Open Beta mod.
    - `_Build TB Official.bat` builds only the Official mod.
    - `_Build TB Open Beta.bat` builds only the Open Beta mod.
- **Important**:
    - Before building the mod make sure to close any application that is accessing the repository folder.
    - Otherwise you will get `[ERROR] Access Denied or folder not found`.

### Uploading the Mod
**DO NOT** use `_Upload Mod.bat` script to update the mod in the steam workshop. 
- **To Upload the Mod** push your changes via [Git](https://git-scm.com/) to the repository.
- This triggers the workflow in `.github/workflows/upload.yml` to upload the most recent build.
    - Depending wether the workflow was triggered on the main repository or the fork, it will upload either the official or open beta version.
    - The upload of the mod itself is handled by our steam bot account [Skavenslave](https://steamcommunity.com/profiles/76561199068515847/).

### Updating Tourney Balance
- To update the official version of Tourney Balance simply create a pull request.
    - Make sure that the last build was made using `_Build TB All.bat`
    - Make sure that **the changes are working!**
- Once the pull request is merged into the main repository, the workflow will automatically trigger and upload the mod to the steam workshop.


