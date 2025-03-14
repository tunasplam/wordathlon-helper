#=
Given a jumble of 5-letter characters, what is the probability that it is a word in english?

Here is a good source of corpi
https://github.com/zydou/high-frequency-words

Remember: this doesnt need to be foolproof, its for a phone game.

Two possible outcomes: word and not word.
Naive Bayes will assign a probability to both.

posterior = (prior *  liklihood) / evidence

denominator is constant so only look at numerator

"naive": assume all features are mutually independent conditional
on the category.

so P(x) = sum_k [ P(C_k) * p(x | C_k) ]

i.e. evidence = sum of the probabilities of each category times
the probability of the evidence given the catgory.

above is the probability model, combine with a decision rule
to get N.B. classifier.

'maximum a posteriori' pick C_k that maximized probability
y_pred = argmax_{k ∈ 1 ... K} p(C_k) product_{i=1}^n p(x_i | C_k)
where K is number of categories,

so probability of category * product of all evidences given that class.
it works bc "naive" assumes conditional independence between the features
so thats why we can just multiply them all together.
=#

using Base.Filesystem
using Random
using Serialization

# TODO i guess we could set this to be length of true corpus so we guarantee balance
NUMBER_FALSE = 5500

function filter_down_to_5_letter_words(f::String)
    #=Takes an input corpus and does exactly as advertised.
    Also generates a false corpus of random letters.
    =#
    words = filter!(s -> length(s) == 5, readlines(f * ".txt"))

    # NOTE not all of the words in corpus are actually words according
    # to meriam webster. Likewise, not all randomly generated strings
    # will not be words. Remember: this is a stretch goal for a hobby
    # project for a stupid phone game.
    # i don't need it to be exact.
    open(splitext(basename(f))[1] * "_filtered.txt", "w") do f
        # true corpus
        for word in words
            println(f, uppercase(word) * ",true")
        end

        # false. this is balanced for the filtered 50k set
        for _ in 1:NUMBER_FALSE
            println(f, uppercase(randstring("abcdefghijklmnopqrstuvwxyz", 5)) * ",false")
        end
    end
end

function create_ngram_frequencies(corpus_fp::String)
    #= create frequency table of tri- bi- and mono-grams and save
    =#
    ts = map(s -> split(s, ','), readlines(corpus_fp * "_filtered.txt"))

    true_corpus_length = length(ts) - NUMBER_FALSE
    false_corpus_length = NUMBER_FALSE
    freqs_true = Dict()
    freqs_false = Dict()

    for t in ts
        freqs = t[2] == "true" ? freqs_true  : freqs_false
        word = t[1]

        # trigrams
        freqs[word[1:3]] = get(freqs, word[1:3], 0) + 1
        freqs[word[2:4]] = get(freqs, word[2:4], 0) + 1
        freqs[word[3:5]] = get(freqs, word[3:5], 0) + 1

        # bigrams
        freqs[word[1:2]] = get(freqs, word[1:2], 0) + 1
        freqs[word[2:3]] = get(freqs, word[2:3], 0) + 1
        freqs[word[3:4]] = get(freqs, word[3:4], 0) + 1
        freqs[word[4:5]] = get(freqs, word[4:5], 0) + 1
    
        for c in word
            freqs[string(c)] = get(freqs, string(c), 0) + 1
        end
    end

    @assert sum(collect(values(freqs_true))) == true_corpus_length * (3 + 4 + 5)
    @assert sum(collect(values(freqs_false))) == false_corpus_length * (3 + 4 + 5)

    serialize(corpus_fp * "_true_frequencies.jls", freqs_true)
    serialize(corpus_fp * "_false_frequencies.jls", freqs_false)
end

function cache_probabilities(corpus_fp::String)
    true_freqs = deserialize(corpus_fp * "_true_frequencies.jls")
    false_freqs = deserialize(corpus_fp * "_false_frequencies.jls")

    ngram_probs_true = Dict()
    ngram_probs_false = Dict()

    num_true_ngrams = sum(collect(values(true_freqs)))
    num_false_ngrams = sum(collect(values(false_freqs)))
    for (ngram, freq) in true_freqs
        ngram_probs_true[ngram] = freq / num_true_ngrams
    end
    for (ngram, freq) in false_freqs
        ngram_probs_false[ngram] = freq / num_false_ngrams
    end

    @assert abs(sum(collect(values(ngram_probs_true)))) - 1 < .0000001
    @assert abs(sum(collect(values(ngram_probs_false)))) - 1 < .0000001

    serialize(corpus_fp * "_true_probabilities.jls", ngram_probs_true)
    serialize(corpus_fp * "_false_probabilities.jls", ngram_probs_false)
end

function calculate_probability(w::String, P_T, P_F, freqs_T, freqs_F)
    # y_pred = argmax_{k ∈ 1 ... K} p(C_k) product_{i=1}^n p(x_i | C_k)
    # for word ABCDE
    # P(T|word) = P(T) *
    #   P(A|T)* .. * P(E|T) *
    #   P(AB|T)* .. *P(DE|T) *   
    #   P(ABC|T)* .. *P(CDE|T)

    # p(T) is the prior
    # likewise for false

    # excellently tuned by literally eyeballing 10 or so strings lol
    prior_true = .00001
    p_true = begin
        prior_true * 
        prod([lookup_P(string(w[i]), P_T, freqs_T) for i in 1:5]) * 
        prod([lookup_P(w[i:i+1], P_T, freqs_T) for i in 1:4]) *
        prod([lookup_P(w[i:i+2], P_T, freqs_T) for i in 1:3])
    end

    p_false = begin
        (1-prior_true) *
        prod([lookup_P(string(w[i]), P_F, freqs_F) for i in 1:5]) *
        prod([lookup_P(w[i:i+1], P_F, freqs_F) for i in 1:4]) *
        prod([lookup_P(w[i:i+2], P_F, freqs_F) for i in 1:3])
    end
    return (p_true, p_false)
end

function lookup_P(feature, probs, features)
    # applies laplace smoothing (we are just adding one but can and should tune that later)
    total_features = sum(collect(values(features)))
    if feature ∉ keys(probs)
        return 1 / (total_features + (length(features) - 1))
    end
    return (features[feature] + 1) / (total_features + (length(features) - 1))
end

function process_corpus(corpus_fp::String)
    corpus_fp = splitext(basename(corpus_fp))[1]
    filter_down_to_5_letter_words(corpus_fp)
    create_ngram_frequencies(corpus_fp)
    cache_probabilities(corpus_fp)
end

function load_probabilities(corpus_fp::String)
    corpus_fp = splitext(basename(corpus_fp))[1]
    return (
        deserialize(corpus_fp * "_true_probabilities.jls"),
        deserialize(corpus_fp * "_false_probabilities.jls")
    )
end

function load_frequencies(corpus_fp::String)
    corpus_fp = splitext(basename(corpus_fp))[1]
    return (
        deserialize(corpus_fp * "_true_frequencies.jls"),
        deserialize(corpus_fp * "_false_frequencies.jls")
    )
end

function main()
    corpus_fp = "50k.txt"
    process_corpus(corpus_fp)
    P_T, P_F = load_probabilities(corpus_fp)
    freqs_T, freqs_F = load_frequencies(corpus_fp)
    # it misses POLIO but honestly its not bad. polio is a weird word
    words = [
        "OLIVE", "LAKOE", "LAEKS", "LAKES", "USAEA", "USERS",
        "CALIK", "POLIO", "POLLS", "PULSX", "POELI", "COCKS"
    ]
    for word in words
        pt, pf = calculate_probability(word, P_T, P_F, freqs_T, freqs_F)
        @show word
        @show pt, pf
        @show pt > pf
    end
end

main()
