#!/bin/sh -l

set -e  # if a command fails it stops the execution
set -u  # script fails if trying to access to an undefined variable

echo "[+] Action start"
KUSTOMIZE_VERSION="${1}"
KUSTOMIZE_IMAGES="${2}"
USER_EMAIL="${3}"
USER_NAME="${4}"
GITHUB_SERVER="${5}"
REPOSITORY_USERNAME="${6}"
REPOSITORY_NAME="${7}"
TARGET_BRANCH="${8}"
TARGET_DIRECTORY="${9}"
COMMIT_MESSAGE="${10}"

ORIGIN_COMMIT="https://$GITHUB_SERVER/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"
COMMIT_MESSAGE="${COMMIT_MESSAGE/\$GITHUB_REF/$GITHUB_REF}"
COMMIT_MESSAGE="${COMMIT_MESSAGE/KUSTOMIZE_IMAGES/$KUSTOMIZE_IMAGES}"

# Make sure we have a version:
if [ -z $KUSTOMIZE_VERSION ]; then
    echo "[+] Downloding Kustomize latest version"
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
else
    echo "[+] Downloding Kustomize $KUSTOMIZE_VERSION version"
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh $KUSTOMIZE_VERSION"  | bash
fi

if [ -z "$USER_NAME" ]; then
	USER_NAME="$REPOSITORY_USERNAME"
fi

CLONE_DIR=$(mktemp -d)

echo "[+] Cloning destination git repository $REPOSITORY_NAME"
# Setup git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

{
	git clone --single-branch --branch "$TARGET_BRANCH" "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$REPOSITORY_USERNAME/$REPOSITORY_NAME.git" "$CLONE_DIR"
} || {
	echo "::error::Could not clone the destination repository. Command:"
	echo "::error::git clone --single-branch --branch $TARGET_BRANCH https://$USER_NAME:the_api_token@$GITHUB_SERVER/$REPOSITORY_USERNAME/$REPOSITORY_NAME.git $CLONE_DIR"
	echo "::error::(Note that the USER_NAME and API_TOKEN is redacted by GitHub)"
	echo "::error::Please verify that the target repository exist AND that it contains the destination branch name, and is accesible by the API_TOKEN_GITHUB"
	exit 1
}

echo "[+] cd into $CLONE_DIR/$TARGET_DIRECTORY"
cd $CLONE_DIR/$TARGET_DIRECTORY

echo "[+] Running Kustomize"
kustomize edit set image $KUSTOMIZE_IMAGES

echo "[+] Adding git commit"
git add .

echo "[+] git status:"
git status

echo "[+] git diff-index:"
# git diff-index : to avoid doing the git commit failing if there are no changes to be commit
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

echo "[+] Pushing git commit"
# --set-upstream: sets de branch when pushing to a branch that does not exist
git push "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$REPOSITORY_USERNAME/$REPOSITORY_NAME.git" --set-upstream "$TARGET_BRANCH"
