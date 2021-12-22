#!/usr/bin/env bash

################################################
# Fichero:	ini.sh
# Autor:	755844 - Sergio Garcia Esteban & 758325 - Irene Fumanal Lacoma
# Descrip:	Script de lanzamiento - Practica 2 Sistemas distribuidos
# Version:	FinalVersion
################################################

iex -r rw.ex -r repositorio.exs --name node$1@127.0.0.1 --erl  '-kernel inet_dist_listen_min 32000' --erl  '-kernel inet_dist_listen_max 32009' --cookie 1234567897
