#!/usr/bin/perl 

use strict;
use warnings;
use 5.12.1;

#1 Create a fake checkout.

use File::Tempdir;
use Path::Class qw( file dir );
use File::pushd;

my $tempdir    = File::Tempdir->new( 'perl-experimental-snapshot.XXXXXX', TMPDIR => 1);
my $dir        = dir( $tempdir->name )->absolute;
my $clone_from = dir('/var/paludis/repositories/perl-git');
my $wd_repo    = dir('/graft/repositories/perl-experimental-snapshot/');

sub notice($) {
    STDERR->say("\e[31m * @_\e[0m");
}

notice "Preparing to make a snapshot of $clone_from";
notice "Preparing snapshots in $wd_repo";
notice "Temporary clone directory is $dir";

{
    my $formatted_message;

    my $wd = pushd( $dir->stringify );
    notice "Entering $dir";

    # Make a clone of master.
    notice "Cloning $clone_from @ master to $dir/src ";
    git_clone( $clone_from, 'src', 'master' );
    notice "Collecting Git commit info";

    my $original_message =
      gitx( "$dir/src", 'log', '-1', '--pretty=format:%h by %aN on %ad%n"%s"',
        'HEAD' );
    my (@lines) = <$original_message>;
    chomp for @lines;
    my ($ts) = scalar gmtime;

    my %data;

    for my $file (qw( timestamp timestamp.chk timestamp.x ) ) {
	$data{$file} = dir('/usr/portage/metadata')->file( $file )->slurp( chomp => 1 );
    }

    my $formatted_message = <<"EOM";
Automated Snapshot Generated at $ts.

Snapshot at Commit on <perl-experimental>:

	$lines[0]
	$lines[1]

PORTDIR SYNC CONTEXT:

/metadata/timestamp 	: $data{timestamp}
/metadata/timestamp.chk : $data{'timestamp.chk'}
/metadata/timestamp.x	: $data{'timestamp.x'}

EOM
    notice "Message: \n$formatted_message";

    # Rsync master into the snapshot dir.
    notice "Selectively rsyncing from $dir/src to $wd_repo";
    rsync(
        "$dir/src/" => "$wd_repo",
        {
            -exclude => [
                '.git',                '/metadata/cache',
                '/metadata/md5-cache', '/profiles/use.local.desc',
                '/profiles/repo_name', '/README',
                '/scripts',
            ],
        },
    );
    {
        notice "Changing Repository Name";
        my $fd = $wd_repo->subdir('profiles')->file('repo_name')->openw();
        $fd->say('perl-experimental-snapshots');
    }
    {
        notice "Making sure metadata/cache exists";
        $wd_repo->subdir('metadata')->subdir('cache')->mkpath();
    }
    {
        notice
"Regenerating portage cache data for overlay: perl-experimental-snapshots located at $wd_repo";
        system(

            #	    'strace', '-e' , 'trace=open',
            'egencache',
            '--update',
            '--update-use-local-desc',
            '--repo=perl-experimental-snapshots',
            '--portdir-overlay=' . $wd_repo,
            '--jobs=2',
            '--load-average=3',
        );
    }
    {
        notice "Entering Git Dir";
        $wd = pushd( $wd_repo->stringify );
        notice "Adding changes to Git Index";
        system( 'git', 'add', '.' );
        system( 'git', 'add', '-u', '.' );

        notice "Committing Changes";

        system( 'git', 'commit', '-m', $formatted_message,
            '--author=Kent Fredric <kentfredric@gmail.com>' );
    }

}

#1 Rsync everything except .git
#
#
sub git_clone {
    my ( $src, $target, $branch ) = @_;
    return system(
        'git', 'clone',   '--progress', '--verbose',
        '-b',  "$branch", "$src",       "$target"
    );
}

sub rsync {
    my ( $src, $dest, $opts ) = @_;
    my (@flags) = (
        qw( --recursive --links --safe-links --perms --times --compress --force --whole-file --stats),
        '-v', '--progress', '-a', '--partial', '-c', '--delete-delay',
    );

    if ( exists $opts->{-exclude} ) {
        for my $to_ex ( @{ $opts->{-exclude} } ) {
            push @flags, '--exclude=' . $to_ex;
        }
    }
    push @flags, $src;
    push @flags, $dest;
    return system( 'rsync', @flags );
}

sub gitx {
    my ( $repo, @cmd ) = @_;
    my $dir = pushd($repo);
    open my $fh, '-|', 'git', @cmd or die;
    return $fh;
}

sub git_head {
    my ( $repo, $ref ) = @_;
    my $fh = gitx( $repo, 'rev-parse', $ref || 'HEAD' );
    my $sha = <$fh>;
    chomp $sha;
    return $sha;
}

