#!/usr/bin/env bash

BUILD_NUMBER=$(git rev-list --count prod)
export BUILD_NUMBER

perl -i -pe 's/^(version:\s+\d+\.\d+\.\d+\+)(\d+)$/$1.$ENV{BUILD_NUMBER}/e' pubspec.yaml