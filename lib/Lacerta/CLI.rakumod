use Terminal::Spinners;
use Text::Table::Simple;

# If no arguments are passed then run USAGE & exit.
proto MAIN(|) is export {unless so @*ARGS {put $*USAGE; exit}; {*}}

#| parses WhatsApp export
multi sub MAIN(
    Str $input where *.IO.f = "input", #= input log file to parse
    Str :$profile-name = "Andinus", #= your WhatsApp profile name
    Int :$no-of-spoken = 3, #= number of Most Spoken columns
) is export {
    #| Parses the WhatsApp logs.
    grammar WhatsApp {
        token TOP { <Text> || <Notice> }

        token Notice { <date> ', ' <time> ' - ' <message> }
        token Text { <date> ', ' <time> ' - ' <name> ': ' <message> }

        token date { (\d+) ** 3 % '/' }
        token time { (\d+) ** 2 % ':' }
        token name { [[\w|\s]+ | '+' \d+ [\d+|\s]+] }
        token number { '+' \d+ [\d+|\s]+ }
        token message { .* }
    }

    my WhatsApp @logs;

    my Instant $timed = now;
    Spinner.new(:type<bounce2>).await: Promise.start: {
        @logs = $input.IO.lines.race.map({WhatsApp.parse($_)}).grep(so *);
    };
    put "Parsed {@logs.elems} logs in " ~ (now - $timed) ~ "s";

    my List @data;
    my List @given-data;
    my List @most-spoken-data;

    $timed = now;
    Spinner.new(:type<bounce>).await: Promise.start: {
        my Promise @promises;
        for @logs.grep(*<Text>).map(*<Text>).map(*<name>.Str).unique -> $name {
            # Messages that weren't sent are logged under "ERROR" name.
            next if $name eq "ERROR";

            # Promise for each names.
            push @promises, start with @logs.grep(*<Text>).map(*<Text>).grep(*<name> eq $name) {
                push @data,
                (
                    $name,
                    .elems,
                    .map(*<message>.words).sum,
                    .grep(*<message> eq ($name eq $profile-name
                                         ?? "You deleted this message" !! "This message was deleted")).elems,
                    .grep(*<message> eq "<Media omitted>").elems,
                    .map(*<time>[0][0].Int).Bag.max(*.values).key,
                    @logs.grep(*<Notice>).grep(*<Notice><message>
                                               eq ($name eq $profile-name ?? "You left" !! "$name left")).elems,
                );
                with .map(*<message>).map(*.lc).cache {
                    push @given-data,
                    (
                        $name,
                        .grep(*.contains: "fuck").elems,
                    );

                    push @most-spoken-data,
                    (
                        $name,
                        .grep(* ne "<media omitted>")
                         .grep(* ne ($name eq $profile-name
                                     ?? "you deleted this message"
                                     !! "this message was deleted")).map(*.words).Bag
                         .grep(*.key.chars >= 4).sort(*.values).reverse
                         .map({"{$_.key} ({$_.value})"}).head($no-of-spoken).Slip,
                    );
                }
            }
        }
        await @promises;
    }
    put "Generated data in " ~ (now - $timed) ~ "s" ~ "\n";

    my List %options = headers => (corner_marker => "*", bottom_border => "-");
    .say for lol2table(<Name Messages Words Deleted Media ActiveHour Left>, @data, |%options);
    .say for lol2table(<Name FucksGiven>, @given-data, |%options);
    .say for lol2table((|<Name MostSpoken-#1>, |("#" X~ (2..$no-of-spoken))), @most-spoken-data, |%options);
}

multi sub MAIN(
    Bool :$version #= print version
) is export { put "Lacerta v" ~ $?DISTRIBUTION.meta<version>; }
