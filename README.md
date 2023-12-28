yaccDate
========
yaccDate was born because I was trying to parse the `Date:` field of about 150000 archived emails from the last 20 years.
It seems that every possible permutation of legal and illegal variations on the Date/Time/TZ theme have been tried.  
parsing dates using `time.Parse()` became frustrating as I had to add more and more templates, and try them, in a loop, parsing the same date field over and over again.
Not only that, since some emails have used unknown timezones,I had to perform some search/replace magic, and then retry all those templates again.  
It became obvious that this is not efficient. I decided to write a single parser that will know to test for different versions while scanning the date string once.

How it works
------------
yaccDate works by writing a generic date/time/timezone template using goYacc. The resulting code is much more efficient and can be easily fixed to add more variations.

Building demo from source
--------------------
```
cd yaccDate
go generate
cd ../main
go generate
```

Using the package
-----------------
Add the following:

```
import (
    "github.com/udif/yaccDate"
)
```

Call the following function:
`func FlexDateToTime(dateStr string) time.Time {}`

License
-------

