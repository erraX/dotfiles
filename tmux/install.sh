#!/bin/sh

# install `diff-so-fancy`
if [ -z "$(brew list | grep reattach-to-user-namespace)" ]
then
  echo "Start install reattach-to-user-namespace"
  brew installreattach-to-user-namespace 
else 
  echo "reattach-to-user-namespace already installed"
fi

# Copy `.gitconfig`
cp ./.tmux.conf ~
cp -r ./.tmux ~

echo "Installation finished!"
