@echo off
cd ..\crackup
call rake clobber
call rake gem

cd ..\crackup-file
call rake clobber
call rake gem

cd ..\crackup-ftp
call rake clobber
call rake gem

cd ..\crackup-gmail
call rake clobber
call rake gem

cd ..\crackup-sftp
call rake clobber
call rake gem

cd ..\crackup-s3
call rake clobber
call rake gem

cd ..\build
pause