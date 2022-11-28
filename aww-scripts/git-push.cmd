@rem combine all the arguments into a single string
@rem and pass it to git commit -am

set message=%*
set currentDate=%date%

@rem if message is empty, set it to "update currentDate"
if "%message%"=="" (
  set message=update %currentDate%
)

git add --all
git commit -am "%message%"
git pull
git push
git status