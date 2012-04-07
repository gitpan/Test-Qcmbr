# ABSTRACT: Cucumber inspired Feature Specification Parser
package Test::Qcmbr;
{
  $Test::Qcmbr::VERSION = '0.00_01';
}

our $VERSION = '0.00_01'; # VERSION

use Exporter;

our @ISA = ('Exporter');
our @EXPORT = qw/
    
    execute_scenario
    execute_scenarios
    
    given
    when
    then
    
    next_scenario
    
    parse_feature
    parse_feature_file
    
/;

our $DATA = {};


sub given {
    
    my ($re, $code) = @_;
    
    push @{$DATA->{'criteria'}->{'given'}}, {
        
        cond => $re,
        code => $code
        
    }
    
}

sub when {
    
    my ($re, $code) = @_;
    
    push @{$DATA->{'criteria'}->{'when'}}, {
        
        cond => $re,
        code => $code
        
    }
    
}

sub then {
    
    my ($re, $code) = @_;
    
    push @{$DATA->{'criteria'}->{'then'}}, {
        
        cond => $re,
        code => $code
        
    }
    
}

sub execute_scenario {
    
    my $scenario = shift;
    
    if ($scenario) {
        
        my $last;
        
        my $spec = $DATA->{specification};
        
        my $data = $spec->{examples}->{$scenario->{example}}
            if $scenario->{example};
        
        foreach my $action (@{$scenario->{actions}}) {
            
            my $type;
            
            $type = 'given' if $action =~ /^given/i;
            $type = 'when'  if $action =~  /^when/i;
            $type = 'then'  if $action =~  /^then/i;
            $type = $last   if $action =~   /^and/i;
            
            my $tests = $DATA->{'criteria'}->{$type};
            
            foreach my $test (@{$tests}) {
                
                if ($action =~ $test->{cond}) {
                    
                    my $i = 0;
                    
                    my @args = $action =~ $test->{cond};
                    
                    $i = $#{$data} if $action =~ /\s:\w+/; # placeholders?
                    
                    $i ||= 1; # run-once at-least
                    
                    for (my $z=0; $z<$i; $z++) {
                        
                        my $row = "ARRAY" eq ref $data ? $data->[$z] : {};
                        
                        my @keys = $action =~ /:(\w+)/g;
                        
                        foreach my $key (@keys) {
                            
                            if (exists $row->{$key}) {
                            
                                my $value = $row->{$key};
                                
                                $action =~ s/:$key/$value/g;
                                
                                push @args, $value;
                            
                            }
                            
                        }
                        
                        $test->{code}->($spec, $action, $row, @args);
                        
                    }
                    
                }
                
            }
            
            $last = $type;
            
        }
        
    }
    
    return 1;
    
}

sub execute_scenarios {
    
    while (my $scenario = next_scenario()) {
        
        execute_scenario $scenario;
        
    }
    
    return 1;
}

sub next_scenario {
    
    if (defined $DATA->{specification}) {
        
        my $position = $DATA->{current_scenario} =
            defined $DATA->{current_scenario} ? ++$DATA->{current_scenario} : 0;
        
        if (defined $DATA->{specification}->{scenarios}->[$position]) {
            
            return $DATA->{specification}->{scenarios}->[$position];
            
        }
        
    }
    
    return undef;
    
}

sub parse_feature {
    
    my $feat = shift;
    
    sub trim {
        
        if ($_[0]) {
            
            if ($_[0] =~ /[^\s\t\r]/) {
                
                $_[0] =~ s/^\s+//;
                $_[0] =~ s/\s+$//;
                
            }
            
        }
        
        $_[0]
        
    }
    
    my $spec = {};
    
    # parse and return specification
    
    my @statements = split /\n/, $feat;
    
    my $section;
    
    foreach my $statement (@statements) {
        
        # skip comments
        unless ($statement =~ /^(?:[\n\s\t]+)?#/) {
            
            # start section parsing
            if ($section) {
                
                # parse feature
                if ($section eq 'feature') {
                    
                    if ($statement =~ /^(?:[\n\s\t]+)?([iI]n\s|[aA]s\s|[iI]\s)/) {
                        
                        push @{$spec->{description}}, trim $statement;
                        
                    }
                    
                }
                
                # parse scenario
                if ($section eq 'scenario') {
                    
                    #Given I am the package MyApp
                    #And I am accessing values using the param method
                    #When I assign the parameter :name a value of :value
                    #Then the parameter hash element :name should match the :result
                    
                    my @opening_lines = (
                        '[aA]nd ',
                        '[gG]iven ',
                        '[wWtT]hen ',
                    );
                    
                    my $opening = join "|", @opening_lines;
                    
                    if ($statement =~ /^(?:[\n\s\t]+)?($opening)/) {
                        
                        my $scenario = $spec->{scenarios}->[-1];
                        
                        push @{$scenario->{actions}}, trim $statement;
                        
                    }
                    
                }
                
                # parse example data
                if ($section eq 'example') {
                    
                    if ($statement =~ /^(?:[\n\s\t]+)?(\|)/) {
                        
                        my $example = $spec->{examples}->[-1];
                        
                        push @{$example->{data}}, [
                            grep { $_ } map { trim $_ }
                                ($statement =~ /(?:\|[^\n])([^\|]+)/g)
                        ];
                        
                    }
                    
                }
                
            }
            
            # start feature parsing
            unless ($section) {
                
                if ($statement =~ /[Ff]eature\:(\s?(.*))/) {
                    
                    $section = 'feature';
                    
                    $spec->{name} = trim (my $name = $2);
                    
                }
                
            }
            
            # start scenario parsing
            if ($statement =~ /[Ss]cenario(\s?(\w+)?)\:(.*)/) {
                
                $section = 'scenario';
                
                my $meta = {};
                
                $meta->{name}    = trim (my $name = $3);
                $meta->{example} = trim (my $data = $2);
                
                push @{$spec->{scenarios}}, $meta;
                
            }
            
            # start example data parsing
            if ($statement =~ /[Ee]xample(\s?(\w+))\:/) {
                
                $section = 'example';
                
                my $meta = {};
                
                $meta->{name} = trim (my $name = $2);
                
                push @{$spec->{examples}}, $meta;
                
            }
        
        }
        
    }
    
    # key examples by name and header
    if ($spec->{examples}) {
        
        foreach my $example (@{$spec->{examples}}) {
            
            my $records = $spec->{keyed_examples}->{$example->{name}} = [];
            
            my $headers = $example->{data}->[0];
            
            for (my $i=1; $i<@{$example->{data}}; $i++) {
                
                my $record = {};
                
                $record->{$headers->[$_]} = $example->{data}->[$i]->[$_]
                    for 0..$#$headers;
                
                push @{$records}, $record;
                
            }
            
        }
        
        $spec->{examples} = delete $spec->{keyed_examples}
            if defined $spec->{keyed_examples};
        
    }
    
    return $DATA->{specification} = $spec;
    
}

sub parse_feature_file {
    
    my $file = shift;
    
    open my $fh, '<', $file or die "error opening $file: $!";
    
    return parse_feature(join('', (<$fh>)));
    
}

1;
__END__
=pod

=head1 NAME

Test::Qcmbr - Cucumber inspired Feature Specification Parser

=head1 VERSION

version 0.00_01

=head1 SYNOPSIS

    use Test::More;
    use Test::Qcmbr;
    
    parse_feature_file $filename;
    
    given qr(.*) => sub {
        
        my ($spec, $action, $data, @captured) = @_;
        
    };
    
    when qr(.*) => sub {
        ok 1, ...
    };
    
    then qr(.*) => sub {
        ok 1, ...
    };
        
    execute_scenarios && done_testing;

=head1 DESCRIPTION

Test::Qcmbr is centered around the parse_specification method which is a homegrown
Cucumber-like feature specification parser which takes a string in the form of a
Gherkin (cucumber feature specification) and produces a Perl hashref representing
that spec.

Input:

    my $spec = parse_specification <<'GHERKIN'
        
        # comments are ignored
        
        Feature: Parameter Handling
            In order to test getting and setting
            As a package using MyApp::Class
            I want to check parameter values
        
        Scenario TrueValues: Assigning True Values
            Given I am the package MyApp
            And I am accessing values using the param method
            When I assign the parameter :name a value of :value
            Then the parameter hash element :name should match the :result
        
        Example TrueValues:
            | name      | value         | result |
            | test      | 001           | 001    |
        
        Scenario NullValues: Assigning Null Values
            Given I am the package MyApp
            And I am accessing values using the param method
            When I assign the parameter :name a value of :value
            Then the parameter hash element :name (is) :result
        
        Example NullValues:
            | name      | value         | result    |
            | test      | null          | defined   |
            | test      | null          | exists    |
        
        Scenario: Testing FunnyBone
            When I set the accessor humor to politics
            Then the method funny will return null
        
    GHERKIN

Output:

    $spec = {
        'name'        => 'Parameter Handling',
        'description' => [
            'In order to test getting and setting',
            'As a package using Validation::Class',
            'I want to check parameter values'
        ],
        'scenarios' => [
            {
                'actions' => [
                    'And I am accessing values using the param method',
                    'When I assign the parameter :name a value of :value',
                    'Then the parameter hash element :name should match the :result'
                ],
                'example' => 'TrueValues',
                'name'    => 'Assigning True Values'
            },
            {
                'actions' => [
                    'And I am accessing values using the param method',
                    'When I assign the parameter :name a value of :value',
                    'Then the parameter hash element :name (is) :result'
                ],
                'example' => 'NullValues',
                'name'    => 'Assigning Null Values'
            },
            {
                'actions' => [
                    'When I assign the parameter :name a value of :value',
                    'Then the parameter hash element :name (is) :result'
                ],
                'example' => undef,
                'name'    => 'Testing The Mexican'
            }
        ],
        'examples' => {
            'NullValues' => [
                [ 'test', 'null', 'defined' ],
                [ 'test', 'null', 'exists' ]
            ],
            'TrueValues' => [
                [ 'test', '001', '001' ]
            ]
        }
    };

The parse method is responsible for turing a feature spec into a Perl data
structure.

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

