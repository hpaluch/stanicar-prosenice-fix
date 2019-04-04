# Simulation fix of `prosenice_1-50.xml`

Here is simple perl script that fixes `prosenice_1-50.xml` simulation
(missing "vozy/vuz" elements). Original simulation file can be downloaded
as http://2koridor.websnadno.cz/prosenice_1-50.zip
from [Prosenice simulation page][Prosenice]

_Stanicar _simulation program is available from: http://www.simulator.websnadno.cz/Ke-stazeni.html

# perl setup

Tested perl - Strawberry perl version `strawberry-perl-5.26.2.1-64bit.msi`.
Current version can be downloaded from http://strawberryperl.com.

Following CPAN packages must be installed before running this perl script:

```cmd
cd /d "C:\Strawberry\perl\bin"
cpanm XML::DOM
cpanm Config::Tiny
:: "-n" to run without tests (they are failing)
cpanm XML::DOM::XPath -n
```

Then just run the script without arguments, for example using:

```cmd
C:\Strawberry\perl\bin\perl.exe fix-missing-fuz.pl
```

There are following input files:
* `prosenice_1-50.xml` - original Prosenice simulation file
* `vozy.ini` - list of "vozy" from `Stag` program

There are following output files:
* `prosenice_1-59-template.xml` - copy of original input file 
  (also it is structurally same it may differ in whitespace
  and attributes order).
* `prosenice_1-59.xml`

NOTE: To detect what exactly changed just
compare `prosenice_1-59-template.xml` and `prosenice_1-59.xml`.


[Prosenice]: http://www.2koridor.websnadno.cz/-----Prosenice.html

