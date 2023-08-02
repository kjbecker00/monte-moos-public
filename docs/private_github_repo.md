# Using a private github repo
To pull from a private github repo, the owner of the repo must generate a fine-grained personal access token (PAT) and give it to you.  
*(note, these are still in beta, so this may need updates in the future)*  
    - To generate a PAT, go to your github account settings, then Developer Settings, then Personal Access Tokens.  
    - Generate a new token with the following permissions:  
        - Commit statuses: read only  
        - Contents: read only  
    - Then, you can add the following line to your repo links:
        - Github: `https:/really_long_personal_access_token@github.com/<your account or organization>/<repo>.git`
        - Gitlab: `https://<username>:<personal_token>@gitlab.com/<your account or organization>/<repo>.git`

See an example of a `repo_links.txt` file: [here](example_files/repo_links.txt)

