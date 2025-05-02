<?php
date_default_timezone_set('UTC');
register_shutdown_function('on_exit');
log_('Installer v1.5 started.'.PHP_EOL);
title('Loading...');
if (file_exists('installed')) unlink('installed');
if (file_exists('failed')) unlink('failed');
touch('closed');

$setup = array(
	'ugold' => array(
		'iso' => 'https://files.oldunreal.net/UNREAL_GOLD.ISO',
		'iso_fallback' => 'https://archive.org/download/totallyunreal/UNREAL_GOLD.ISO',
		'iso_size' => 676734976,
		'patch_fallback' => 'https://api.github.com/repos/OldUnreal/Unreal-testing/releases/tags/v227k_12',
		'patch' => 'https://api.github.com/repos/OldUnreal/Unreal-testing/releases/latest',
		'exe' => 'Unreal.exe',
	),
	'ut99' => array(
		'iso' => 'https://files.oldunreal.net/UT_GOTY_CD1.ISO',
		'iso_fallback' => 'https://archive.org/download/ut-goty/UT_GOTY_CD1.iso',
		'iso_size' => 649633792,
		'patch' => 'https://api.github.com/repos/OldUnreal/UnrealTournamentPatches/releases/latest',
		'exe' => 'UnrealTournament.exe',
	),
);
$game = isset($argv[1]) ? $argv[1] : '';
if (!$game || !isset($setup[$game])) die('Unknown game.');

$keep_files = false;
$from_cd = false;
foreach ($argv as $arg) {
	if ($arg == 'keep_files') $keep_files = true;
	if ($arg == 'from_cd') $from_cd = true;
}

$config = $setup[$game];

$cd_drive = false;
if ($from_cd) {
	title('Check CD drives...');
	foreach (range('A', 'Z') as $disk) {
		if (file_exists($disk.':\\Textures\\Palettes.utx') &&
			file_exists($disk.':\\System\\'.$config['exe'])) {
			$cd_drive = $disk;
			log_('Detected compatible CD disk: '.$cd_drive);
			break;
		}
	}
}

if ($cd_drive) {
	$progress = 'Copy files from CD... ';
	title($progress);

	$skip = array();
	$skip[strtolower(basename($config['exe'], '.exe').'.ini')] = 1;
	$skip['user.ini'] = 1;
	$dirs = array('Help', 'Manuals', 'Maps', 'Music', 'NetGamesUSA.com', 'Sounds', 'System', 'SystemLocalized', 'Textures', 'Web');
	$count_dirs = count($dirs);
	$time = microtime(true);
	foreach ($dirs as $i => $dir) {
		$files = glob_recursive($cd_drive.':/'.$dir.'/*');
		$done = 0;
		$cnt = count($files)*$count_dirs;
		foreach ($files as $done => $file) {
			if ($print = (microtime(true) - $time > 1)) {
				$time = microtime(true);
			}
			if ($print) title($progress.round(100.0*$i/$count_dirs + 100.0*$done/$cnt, 1).'%');
			if (is_dir($file)) continue;
			$name = strtolower(basename($file));
			if (isset($skip[$name]) || preg_match('~/System/[^/]*[.](ct|de|el|es|fr|in|it|nl|pt|ru)t$~i', $file)) continue;
			$to = '..'.substr($file, 2);
			$todir = dirname($to);
			if (!file_exists($todir)) {
				mkdir($todir, 0777, true);
			}
			if (!copy($file, $to)) {
				log_('Copy Failed. Return back to use ISO. Bad file: '.$file.' -> '.$to);
				$cd_drive = false;
				break;
			}
			// Prserve modify time
			touch($to, filemtime($file), fileatime($file));
		}
		if (!$cd_drive) break;
	}
	unset($files);
	unset($skip);
	if ($cd_drive) title($progress.'100%');
}
if (!$cd_drive) {
	title('Downloading game ISO...');

	$file = false;
	$tries = isset($config['iso_fallback']) ? 2 : 1;
	for ($try = 1; $try <= $tries; $try++) {
		if ($try == 2) {
			if ($file && file_exists($file)) unlink($file);
			$config['iso'] = $config['iso_fallback'];
			unset($config['iso_fallback']);
		}
		log_('Try obtain game ISO from '.$config['iso']);
		$file = basename($config['iso']);

		get_file($config['iso'], $config['iso_size'], $try == $tries);

		if (!file_exists($file)) {
			if ($try != $tries) continue;
			end_('Failed get game ISO from '.$config['iso']);
		}

		if (filesize($file) == $config['iso_size']) break;
	}
}

$win_ver = php_uname('r');
log_('Detected Windows version: '.$win_ver);
$win_vista = '6.0';
$win_xp = $game == 'ut99' && floatval($win_ver) < floatval($win_vista);
log_('Compare with Vista version ('.$win_vista.'): '.($win_xp ? 'Use WindowsXP build' : 'Use build for modern Windows (Vista or above)'));

title('Downloading patch releases list...');

$file = false;
$tries = isset($config['patch_fallback']) ? 2 : 1;
for ($try = 1; $try <= $tries; $try++) {
	if ($try == 2) {
		if ($file && file_exists($file)) unlink($file);
		$config['patch'] = $config['patch_fallback'];
		unset($config['patch_fallback']);
	}
	log_('Try obtain releases list from '.$config['patch']);
	$file = basename($config['patch']);

	get_file($config['patch'], -1, $try == $tries);

	if (!file_exists($file)) {
		if ($try != $tries) continue;
		end_('Failed get releases list from '.$config['patch']);
	}
	$releases = file_get_contents($file);
	$list = json_decode($releases, true);
	if (!$list) {
		if ($try != $tries) continue;
		end_('Failed decode as JSON:'.PHP_EOL.'--- start ---'.PHP_EOL.$releases.PHP_EOL.'--- end ---');
	}
	if (!isset($list['assets'])) {
		if ($try != $tries) continue;
		json_error($releases, 'assets not found');
	}
	if (empty($list['assets'])) {
		if ($try != $tries) continue;
		json_error($releases, 'assets empty');
	}
	$patch = false;
	foreach ($list['assets'] as $asset) {
		if (strpos($asset['name'], '-Windows') && strpos($asset['name'], '.zip') && strpos($asset['name'], '-WindowsXP') == $win_xp) {
			$patch = $asset;
		}
	}
	if (!$patch) {
		if ($try != $tries) continue;
		json_error($releases, 'no matching asset');
	}
}
log_('Use '.basename($patch['browser_download_url']).' for patch.');

title('Downloading patch ZIP...');

get_file($patch['browser_download_url'], $patch['size']);

$cmd_7z = 'tools\7z x -aoa -o.. -bsp1 ';

if (!$cd_drive) {
	title('Unpacking game ISO...');

	run($cmd_7z.'-x@skip.txt '.escapeshellarg(basename($config['iso'])));
}

if ($game == 'ut99') {
	title('Unpacking Bonus Pack 4...');

	run($cmd_7z.'"utbonuspack4-zip.7z"');
}

title('Unpacking patch ZIP...');

run($cmd_7z.escapeshellarg(basename($patch['browser_download_url'])));

$progress = 'Unpacking game files... ';
title($progress);

$uzs = glob_recursive('../*.uz');
if ($uzs) run('tools\uz decompress "..\Maps\*.uz"');
$done = 0;
$cnt = count($uzs);
foreach ($uzs as $uz) {
	title($progress.round(100.0*$done++/$cnt, 1).'%');
	log_('Unpack '.$uz);
	$dir = dirname($uz);
	$file = basename($uz, '.uz');
	if (file_exists($dir.'/'.$file)) {
		log_('Already unpacked. Remove uz file.');
		unlink($uz);
		continue;
	}
	run('..\System\ucc decompress '.escapeshellarg($uz));
	if (realpath($dir) != realpath('../System')) {
		if (file_exists('../System/'.$file)) {
			rename('../System/'.$file, $dir.'/'.$file);
		}
	}
	if (file_exists($dir.'/'.$file)) {
		log_('Unpacked. Remove uz file.');
		unlink($uz);
	}
}
unset($uzs);

title('Special fixes...');

if (file_exists($copy_src = '../Maps/DM-Cybrosis][.unr') && !file_exists($copy_dest = '../Maps/DOM-Cybrosis][.unr')) {
	copy($copy_src, $copy_dest);
}

title('Alter game configuration...');

if ($game == 'ut99') {
	copy('UnrealTournament.ini', '../System/UnrealTournament.ini');
	copy('User.ini', '../System/User.ini');
}

title('Remove downloaded files...');

if (!$keep_files) {
	unlink(basename($config['patch']));
	unlink(basename($config['iso']));
	unlink(basename($patch['browser_download_url']));
}

title('Game installed');
log_('Game installed'.str_repeat(PHP_EOL, 20));

touch('installed');
end_('Game installed sucessfully.'.PHP_EOL, 0);

function glob_recursive($pattern, $flags = 0) {
	$files = glob($pattern, $flags);
	foreach (glob(dirname($pattern).'/*', GLOB_ONLYDIR|GLOB_NOSORT) as $dir) {
		$files = array_merge($files, glob_recursive($dir.'/'.basename($pattern), $flags));
	}
	return $files;
}

function on_exit() {
	log_('Installer exit.'.PHP_EOL);
	if (file_exists('closed')) unlink('closed');
}

function title($title) {
	log_($title);
	shell_exec('title '.$title);
}

function run($cmd) {
	log_('Execute: '.$cmd);
	$result = 42;
	passthru($cmd, $result);

	log_('Result: '.$result);
	return $result;
}

function get_file($url, $expected_size, $die = true) {
	$file = basename($url);
	if (file_exists($file)) {
		if ($expected_size < 0) {
			log_('Force download requested. Remove old file and try download it again.');
			unlink($file);
		} else {
			$filesize = filesize($file);
			log_('Found '.$file.' of size '.human_size($filesize));
			if ($filesize == $expected_size) {
				log_('Size match to expected size. Use that file.');
			} else {
				log_('Size not match to expected size ('.human_size($expected_size).'). Remove file and try download it again.');
				unlink($file);
			}
		}
	}

	if (!file_exists($file)) {
		download($url, $expected_size, $die);
	}
}

function json_error($json, $error) {
	end_('Unexpected JSON data ('.$error.'):'.PHP_EOL.'--- start ---'.PHP_EOL.$json.PHP_EOL.'--- end ---');
}

function download($url, $expected_size, $die = true) {
	$result_file = basename($url);
	log_('Start download '.$result_file.' from '.$url);

	$insecure = date('Y') < 2025 ? '--check-certificate=false ' : ''; // Wrong date -> TLS will fail (cert not yet issued) -> use insecure connection.
	if ($insecure) log_('Wrong current date on computer detected ('.date('Y-m-d').'). Use insecure connection.');
	$result = run('tools\aria2c --enable-color=false --allow-overwrite=true --auto-file-renaming=false -x5 --ca-certificate=tools\ca-certificates.crt -o '.
		escapeshellarg($result_file).' '.$insecure.escapeshellarg($url));

	if ($result != 0) {
		if (!$die) return;
		end_('Failed download '.$result_file.' from '.$url.'. Abort.');
	}

	if (!file_exists($result_file)) {
		if (!$die) return;
		end_('File '.$result_file.' not found. Abort.');
	}

	if ($expected_size < 0) return;

	$filesize = filesize($result_file);
	if ($filesize != $expected_size) {
		log_('File size of '.$result_file.' is '.human_size($filesize).
			', which not match expect size '.human_size($expected_size));
		if ($filesize < 16) {
			if (!$die) return;
			end_('File size of '.$result_file.' is too small. Abort.');
		}
	}
}

function human_size($filesize) {
	return number_format($filesize, 0, '', ' ');
}

function log_($line) {
	$line = date('Y-m-d H:i:s> ').$line.PHP_EOL;
	echo $line;
	file_put_contents('install.log', $line, FILE_APPEND);
}

function end_($reason, $code = 1) {
	log_($reason.PHP_EOL);
//	log_('Press Enter to close this window.');
//	fgetc(STDIN);
	die($code);
}