#!/usr/bin/env bash
ppa=avsm/ocaml41+opam11
echo "yes" | sudo add-apt-repository ppa:$ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam

export OPAMYES=1
# export OPAMVERBOSE=1  # uncomment this to get more debug info
opam init
opam install mirage
eval `opam config env`

mirage configure --$MIRAGE_BACKEND
mirage build

#############################
# DEPLOYMENT
#
# push a compressed xen VM to a specific repo (for deployment elsewhere)
if [ "$MIRAGE_BACKEND" = "xen" -a "$DEPLOY" = "1" -a "$TRAVIS_PULL_REQUEST" = "false" ]; then

    # load up github SSH key and set up hosts file
    opam install travis-senv
    SSH_DEPLOY_KEY=~/.ssh/id_rsa    
    mkdir -p ~/.ssh
    travis-senv decrypt > $SSH_DEPLOY_KEY
    chmod 600 $SSH_DEPLOY_KEY # owner can read and write
    echo "Host $DEPLOY_USER github.com"   >> ~/.ssh/config
    echo "  Hostname github.com"          >> ~/.ssh/config
    echo "  StrictHostKeyChecking no"     >> ~/.ssh/config
    echo "  CheckHostIP no"               >> ~/.ssh/config
    echo "  UserKnownHostsFile=/dev/null" >> ~/.ssh/config

    # configure travis git details
    #git config --global user.email "user@example.com" # this doesn't exist
    #git config --global user.name "Travis Build Bot"

    # Do the actual work for deployment
    git clone git@deploy-user:amirmc/www-test-deploy
    cd www-test-deploy
    rm -rf $TRAVIS_COMMIT     # to replace previous if being rebult
    mkdir -p $TRAVIS_COMMIT
    cp ../mir-www.xen ../config.ml $TRAVIS_COMMIT
    bzip2 -9 $TRAVIS_COMMIT/mir-www.xen
    git pull --rebase   # in case there are changes since cloning
    echo $TRAVIS_COMMIT > latest    # update ref to most recent
    git add $TRAVIS_COMMIT latest         # add VM and ref to staging

    # commit and push the changes
    git commit -m "adding $TRAVIS_COMMIT built for $MIRAGE_BACKEND"
    git push origin master
fi
