use Terminal::Table;
use Terminal::Spinners;

# Parses the WhatsApp logs.
grammar WhatsApp {
    token TOP {
        || <Text>
        || <Notice>
    }

    token Notice { <date> ', ' <time> ' - ' <message> }
    token Text { <date> ', ' <time> ' - ' <name> ': ' <message> }

    token date { (\d+) ** 3 % '/' }
    token time { (\d+) ** 2 % ':' }
    token name { [[\w|\s]+ | '+' \d+ [\d+|\s]+] }
    token number { '+' \d+ [\d+|\s]+ }
    token message { .* }
}

#| parses WhatsApp export
sub MAIN (
    Str $profile-name = "Andinus", #= WhatsApp profile name
    Str $input where *.IO.f = "input", #= input log file to parse

) {
    my WhatsApp @logs;
    {
        my $bar = Bar.new: :type<equals>;
        $bar.show: 0;

        my Int $count = 0;
        my Int $total = $input.IO.lines.elems; # Roughly the number of messages.
        my Int $interval = $total div 40; # Interval for update.

        @logs = gather for $input.IO.lines -> $line {
            if WhatsApp.parse($line) -> $m { take $m }
            $bar.show: $count / $total * 100 if $count++ %% $interval;
        }
        $bar.show: 100;

        put "\n" ~ "Parsed {@logs.elems} logs in " ~ (now - ENTER now) ~ "s";
    }

    {
        my @data;
        my @given-data;
        push @data, <Name Messages Words Deleted Media MostActiveHour Left>;
        push @given-data, <Name FucksGiven>;
        for @logs.grep(*<Text>).map(*<Text>).map(*<name>.Str).unique -> $name {
            with @logs.grep(*<Text>).map(*<Text>).grep(*<name>.Str eq $name) {
                @data.push(
                    (
                        $name,
                        .elems.Str,
                        .map(*<message>.words).sum.Str,
                        .grep(*<message> eq "You deleted this message"|"This message was deleted").elems.Str,
                        .grep(*<message> eq "<Media omitted>").elems.Str,
                        .map(*<time>[0][0].Int).Bag.max(*.values).key.Str,
                        $name eq $profile-name
                         ?? @logs.grep(*<Notice>).grep(*<Notice><message> eq "You left").elems.Str
                         !! @logs.grep(*<Notice>).grep(*<Notice><message> eq "{$name} left").elems.Str,
                    )
                );

                @given-data.push(
                    (
                        $name,
                        .grep(*<message>.lc.contains("fuck")).elems.Str,
                    )
                );
            }
        }
        put "Generated data in " ~ (now - ENTER now) ~ "s";
        print-table(@data, :style<single>);
        print-table(@given-data, :style<single>);
    }
}
