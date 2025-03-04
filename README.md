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

### Sample run

`julia wordathlon-helper.jl -s "D**L*" -p DFFEALT`

```
Possible words:
DEALT
```

### Notes
API calls are limited 1000 per day for free tier. However, they are cached so if you enter in a word and it unlocks a hint, if you rerun with the new information then all API calls on the rerun should be cache hits.

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
