#!/bin/sh

# install `diff-so-fancy`
if [ -z "$(brew list | grep diff-so-fancy)" ]
then
  echo "Start install diff-so-fancy"
  brew install diff-so-fancy
else 
  echo "diff-so-fancy already installed"
fi

# Copy `.gitconfig`
cp ./.gitconfig ~

# Copy fish shell alias
mkdir -p ~/.config/fish/conf.d >/dev/null 2>&1
cp ./git_alias.fish ~/.config/fish/conf.d

echo "Installation finished!"
