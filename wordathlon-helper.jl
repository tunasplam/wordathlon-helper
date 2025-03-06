#=
Because sometimes im super certain that things are not actually words.

TODO this is now really slow

TODO well, ACKEE was just found to work in wordathlon
Meriam webster does not say its a word
furthermore, the "define word" button mysterious disappeared
after submitting ackee. So, I am thinking that we migrate
to a new strategy:

1. scan meriam webseter
2. probability model
3. scan the gigantic 1-billion word lookup for what works
    -> you could probably somehow save the 1-billion word
    corpus into a BST or something. store it in a database
    with btree inde.
=#

using ArgParse
using Combinatorics
using DotEnv
using HTTP
using JSON

const impossible_combos = [
    "BX", "CJ", "CV", "CX", "DX", "FQ", "FX", "GQ", "GX", "HX", "JC", "JF", "JG", "JQ", "JS",
    "JV", "JW", "JX", "JZ", "KQ", "KX", "MX", "PX", "PZ", "QB", "QC", "QD", "QF", "QG", "QH",
    "QJ", "QK", "QL", "QM", "QN", "QP", "QS", "QT", "QV", "QW", "QX", "QY", "QZ", "SX", "VB",
    "VF", "VH", "VJ", "VM", "VP", "VQ", "VT", "VW", "VX", "WX", "XJ", "XX", "ZJ", "ZQ", "ZX"
]

const cache_fp = ENV["HOME"] * "/.cache/wordathlon-helper/cache.json"

function env_vars()
    env_fp = ENV["HOME"] * "/.config/wordathlon-helper/.env"
    try
        DotEnv.load!(env_fp)
        @assert haskey(ENV, "DICTIONARY_API_KEY")
    catch SystemError
        mkdir(ENV["HOME"] * "/.config/wordathlon-helper")
        mkdir(ENV["HOME"] * "/.cache/wordathlon-helper")
        cp(".env.sample", env_fp)
        println("Navigate to ~/.config/wordathlon-helper/.env and put in your API key.")
        exit()
    end
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--solution-string", "-s"
            help = "What you know about the solution already where * is empty. i.e. A**S*. Should always be 5 characters long."
            arg_type = String
            required = true
        "--pool", "-p"
            help = "Potential letters to draw from. i.e. GYYYOFYL"
            arg_type = String
            required = true
    end

    return parse_args(s)
end

function validate_args(s::Dict{String, Any})
    allowed_chars = Set('A':'Z')
    @assert length(s["solution-string"]) == 5
    @assert all(c -> c in allowed_chars ∪ Set('*'), s["solution-string"])
    @assert all(c -> c in allowed_chars, s["pool"])
end

function handle_args()::Dict{String, Any}
    # accepts, transforms, and validates commandline args
    args = parse_commandline()
    args["solution-string"] = uppercase(args["solution-string"])
    args["pool"] = uppercase(args["pool"])
    validate_args(args)
    return args
end

function generate_test_strings(s::String, p::String)::Vector{String}
    nfree = count(c -> c == '*', s)
    p = collect(p)

    # make sure fixed values are filtered from p
    fixed_chars = filter(c -> c != '*', collect(s))
    for c in fixed_chars
        p = deleteat!(p, findall(x -> x == c, p)[1])
    end

    res = []
    for comb in permutations(p, nfree)
        # determine indicies of free chars. then sub in chars of comb
        s_i = collect(s)
        for (i, j) in enumerate(findall(c -> c == '*', s))
            s_i[j] = comb[i]
        end
        push!(res, join(s_i))
    end
    return res
end

function filter_bad_strings(test_strings::Vector{String})::Vector{String}
    # TODO this could certainly be improved
    #=
    So this is actually a non-trivial problem. bigrams, sure, thatll work. we could
    also probably maybe include trigrams. but in all honesty, this isnt going to happen.
    =#

    # to bring in all words.
    return filter(s -> ! any(occursin(combo, s) for combo in impossible_combos), test_strings)
end

function is_word(s::String, api_key::String)::Bool
    #=The app uses Meriam Webster dictionary so hitting their api to see if strings are words.
    =#
    res = cached_api_call(s, api_key)

    # if its utter gibberish and there are no suggestions then this triggers
    if length(res) == 0
        return false

    # sometimes is returns a list of similar words. this happens if
    # your search doesnt get an exact hit and it is suggesting similar words.
    # for some reaons, GULLY is bucking this trend.
    elseif typeof(res[1]) == String && lowercase(s) in res
        return true

    # otherwise, it returns a dict. see if word is in stems
    elseif typeof(res[1]) == Dict{String, Any} && lowercase(s) in res[1]["meta"]["stems"]
        return true
    end
    return false
end

#=
These functions below are related to cached api calls.They go in ~/.cache/wordathlon-helper/cache.json
=#

function load_cache()
    return isfile(cache_fp) ? JSON.parsefile(cache_fp) : Dict()
end

function save_cache(cache::Dict)
    open(cache_fp, "w") do f
        JSON.print(f, cache)
    end
end

function cached_api_call(s::String, api_key::String)::Union{Vector, Dict}
    cache = load_cache()
    url = "https://www.dictionaryapi.com/api/v3/references/collegiate/json/$(lowercase(s))?key=$(api_key)"

    if haskey(cache, url)
        return cache[url]
    else
        resp = HTTP.get(url)
        if resp.status == 200
            res = JSON.parse(String(resp.body))
            cache[url] = res
            # TODO could optimize by saving cache at end of program rather than each uncached api call
            save_cache(cache)
            return res
        end
    end
end


function main()
    env_vars()
    api_key = get(ENV, "DICTIONARY_API_KEY", nothing)
    args = handle_args()
    test_strings = unique(generate_test_strings(args["solution-string"], args["pool"]))
    test_strings = filter_bad_strings(test_strings)
    test_strings = filter!(s -> is_word(s, api_key), test_strings)
    println("Try these words")
    for s in test_strings
        println(s)
    end
end

main()
