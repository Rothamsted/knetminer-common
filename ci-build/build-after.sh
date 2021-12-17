git diff --exit-code --quiet && return

git commit -m "Upgrading version ref. in create-project.sh [ci skip]" knetminer-archetype/create-project.sh
NEEDS_PUSH=true
