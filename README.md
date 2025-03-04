# wordathlon-helper

### Usage
```
usage: wordathlon-helper.jl -s SOLUTION-STRING -p POOL [-h]

optional arguments:
  -s, --solution-string SOLUTION-STRING
                        What you know about the solution already where
                        * is empty. i.e. A**S*. Should always be 5
                        characters long.
  -p, --pool POOL       Potential letters to draw from. i.e. GYYYOFYL
  -h, --help            show this help message and exit
```

## Setup

### Install required packages in REPL

```
using Pkg
for p in ("ArgParse", "HTTP", "JSON", "Combinatorics", "DotEnv")
    Pkg.add(p)
end
```

### API Key
Go to Meriam Webster and get an API key [here](https://dictionaryapi.com/register/index). First time run creates `~/.config/wordathlon-helper/.env`. Put your API key there.
