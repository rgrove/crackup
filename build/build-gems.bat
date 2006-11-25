@echo off
cd ..\crackup
call rake clobber
call rake pkg/crackup-1.0.2.gem

cd ..\crackup-file
call rake clobber
call rake pkg/crackup-file-1.0.2.gem

cd ..\crackup-ftp
call rake clobber
call rake pkg/crackup-ftp-1.0.2.gem

cd ..\crackup-sftp
call rake clobber
call rake pkg/crackup-sftp-1.0.0.gem

cd ..\crackup-s3
call rake clobber
call rake pkg/crackup-s3-1.0.0.gem

cd ..\build
pause