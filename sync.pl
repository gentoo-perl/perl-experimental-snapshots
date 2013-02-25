#!/usr/bin/perl 

use strict;
use warnings;
use 5.12.1;

my $sync = Syncer->new(
  clone_from_path  => '/var/paludis/repositories/perl-git',
  git_author       => 'Kent Fredric <kentfredric@gmail.com>',
  repo_name        => 'perl-experimental-snapshots',
  tempdir_template => 'perl-experimental-snapshot.XXXXXX',
  wd_repo_path     => '/graft/repositories/perl-experimental-snapshot/',
);

$sync->notice_prelude;
$sync->do_fix_reponame;
$sync->do_fix_metadata_cache;
$sync->do_egencache;
$sync->do_gitcommit;
$sync->notice( $sync->formatted_message );

BEGIN {

  package Syncer;
  use Moo;
  use File::pushd;

  sub lsub($&) {
    my ( $name, $code ) = @_;
    {
      no strict 'refs';
      *{ __PACKAGE__ . '::_build_' . $name } = $code;
    }
    has( $name, ( is => 'lazy' ) );
  }

  lsub clone_from              => sub { dir( $_[0]->clone_from_path ) };
  lsub clone_from_path         => sub { '/var/paludis/repositories/perl-git' };
  lsub cloned_dir              => sub { $_[0]->do_clone_dir; $_[0]->tempdir };
  lsub file_timestamp          => sub { $_[0]->metadata_dir->file('timestamp') };
  lsub file_timestamp_chk      => sub { $_[0]->metadata_dir->file('timestamp.chk') };
  lsub file_timestamp_chk_data => sub { slurp( $_[0]->file_timestamp_chk ) };
  lsub file_timestamp_data     => sub { slurp( $_[0]->file_timestamp ) };
  lsub file_timestamp_x        => sub { $_[0]->metadata_dir->file('timestamp.x') };
  lsub file_timestamp_x_data   => sub { slurp( $_[0]->file_timestamp_x ) };
  lsub git_author              => sub { 'Kent Fredric <kentfredric@gmail.com>' };
  lsub metadata_dir            => sub { dir( $_[0]->metadata_dir_path ) };
  lsub metadata_dir_path       => sub { '/usr/portage/metadata' };
  lsub repo_name               => sub { 'perl-experimental-snapshots' };
  lsub source_repo_name        => sub { 'perl-experimental' };
  lsub rsynced_dir             => sub { $_[0]->do_rsync_dir; $_[0]->wd_repo };
  lsub stderr                  => sub { \*STDERR };
  lsub tempdir                 => sub { dir( $_[0]->tempdir_object->name )->absolute };
  lsub tempdir_object          => sub { tmpdir( $_[0]->tempdir_template, TMPDIR => 1 ) };
  lsub tempdir_template        => sub { 'perl-experimental-snapshot.XXXXXX' };
  lsub timestamp               => sub { scalar gmtime };
  lsub wd_repo                 => sub { dir( $_[0]->wd_repo_path ) };
  lsub wd_repo_path            => sub { '/graft/repositories/perl-experimental-snapshot/' };

  lsub rsync_exclude => sub {
    [
      '.git',                '/metadata/cache', '/metadata/md5-cache', '/profiles/use.local.desc',
      '/profiles/repo_name', '/README',         '/scripts',
    ];
  };

  lsub 'formatted_message' => sub {
    my ( $self, ) = @_;

    my (@message) = map { sprintf "\t%s", $_ } @{ $self->original_message };
    my (%data) = (
      ts            => $self->timestamp,
      timestamp     => $self->file_timestamp_data,
      timestamp_chk => $self->file_timestamp_chk_data,
      timestamp_x   => $self->file_timestamp_x_data,
    );
    return join qq{\n},
      ( sprintf 'Automated Snapshot Generated at %s.', $data{ts} ), '',
      ( sprintf 'Snapshot at Commit on <%s>:', $self->source_repo_name ), '',
      @message, '',
      'PORTDIR SYNC CONTEXT:', '',
      ( sprintf '%-30s : %s', '/metadata/timestamp',     $data{timestamp} ),
      ( sprintf '%-30s : %s', '/metadata/timestamp.chk', $data{timestamp_chk} ),
      ( sprintf '%-30s : %s', '/metadata/timestamp.x',   $data{timestamp_x} );
  };

  lsub 'original_message' => sub {
    my ( $self, ) = @_;
    my $orign = gitx(
      $self->cloned_dir->subdir('src')->stringify,
      'log', '-1', '--pretty=format:%h by %aN on %ad%n"%s"',
      '--dirstat=files,0', 'HEAD'
    );
    my (@lines) = <$orign>;
    chomp for @lines;
    return \@lines;

  };

  sub do_clone_dir {
    my ( $self, ) = @_;
    my $wd = pushd( $self->tempdir->stringify );
    $self->noticef( 'Entering %s', $self->tempdir );
    $self->noticef( 'Cloning %s @ master to %s', $self->clone_from, $self->tempdir->subdir('src') );
    if ( git_clone( $self->clone_from, 'src', 'master' ) != 0 ) {
      die "Clone failed";
    }
  }

  sub do_rsync_dir {
    my ( $self, ) = @_;
    my $src       = $self->cloned_dir->subdir('src');
    my $wd_repo   = $self->wd_repo;

    $self->noticef( 'Selectively syncing from %s to %s', $src, $wd_repo );

    if ( rsync( "$src/" => "$wd_repo/", { -exclude => $self->rsync_exclude }, ) != 0 ) {
      die "Rsync failed";
    }

  }

  sub do_fix_reponame {
    my ( $self, ) = @_;
    my $rdir = $self->rsynced_dir;
    $self->notice("Changing Repository Name");
    my $fd = $rdir->subdir('profiles')->file('repo_name')->openw();
    $fd->say( $self->repo_name );
  }

  sub do_fix_metadata_cache {
    my ( $self, ) = @_;
    $self->notice('Making sure metadata/cache exists');
    $self->rsynced_dir->subdir('metadata')->subdir('cache')->mkpath();
  }

  sub do_egencache {
    my ( $self, ) = @_;
    my $wd = pushd( $self->rsynced_dir->stringify );
    $self->notice('Generating Cache');
    my $exit = system(
      'egencache', '--update', '--update-use-local-desc',
      '--repo=perl-experimental-snapshots',
      '--portdir-overlay=' . $self->rsynced_dir,
      '--jobs=2', '--load-average=3',
    );
    if ( $exit != 0 ) {
      die "egencache failed!";
    }
  }

  sub do_gitcommit {
    my ( $self, ) = @_;
    my $message = $self->formatted_message;
    $self->notice('Entering Git Dir');
    my $wd = pushd( $self->rsynced_dir->stringify );
    $self->notice('Adding changes to Git Index');
    system( 'git', 'add', '.' );
    system( 'git', 'add', '-u', '.' );

    $self->notice('Committing Changes');

    system( 'git', 'commit', '-m', $message, '--author=' . $self->git_author );

  }

  sub notice {
    my ( $self, @message ) = @_;
    $self->stderr->say("\e[31m * @message\e[0m");
  }

  sub noticef {
    my ( $self, $format, @args ) = @_;
    $self->stderr->say( sprintf "\e[31m * $format\e[0m", @args );
  }

  sub notice_prelude {
    my ( $self, ) = @_;
    $self->noticef( 'Preparing to make a snapshot of %s', $self->clone_from );
    $self->noticef( 'Preparing to make snapshots in %s',  $self->wd_repo );
    $self->noticef( 'Temporary clone directory is %s',    $self->tempdir );
  }

  sub dir {
    require Path::Class;
    goto \&Path::Class::dir;
  }

  sub tmpdir {
    require File::Tempdir;
    unshift @_, 'File::Tempdir';
    goto \&File::Tempdir::new;
  }

  sub slurp {
    my ($file) = @_;
    return scalar $file->slurp( chomp => 1 );
  }

  sub git_clone {
    my ( $src, $target, $branch ) = @_;
    return system( 'git', 'clone', '--progress', '--verbose', '-b', "$branch", "$src", "$target" );
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

}

