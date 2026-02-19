<?php
date_default_timezone_set('UTC');
register_shutdown_function('on_exit');
chdir(dirname(__FILE__));
log_('Installer v1.10 started.'.PHP_EOL);
title('Loading...');
if (file_exists('installed')) unlink('installed');
if (file_exists('failed')) unlink('failed');
touch('closed');

$setup = array(
	'ugold' => array(
		'iso' => array(
			'https://files.oldunreal.net/UNREAL_GOLD.ISO' => '676734976_a2dc0525242fce78c01e95b71914a3b4',
			'https://archive.org/download/totallyunreal/UNREAL_GOLD.ISO' => '676734976_a2dc0525242fce78c01e95b71914a3b4',
		),
		'patch_fallback' => 'https://api.github.com/repos/OldUnreal/Unreal-testing/releases/tags/v227k_13',
		'patch' => 'https://api.github.com/repos/OldUnreal/Unreal-testing/releases/latest',
		'exe' => 'Unreal.exe',
	),
	'ut99' => array(
		'iso' => array(
			'https://files.oldunreal.net/UT_GOTY_CD1.ISO' => '649633792_e5127537f44086f5ed36a9d29f992c00',
			'https://archive.org/download/ut-goty/UT_GOTY_CD1.iso' => '649633792_e5127537f44086f5ed36a9d29f992c00',
		),
		'patch' => 'https://api.github.com/repos/OldUnreal/UnrealTournamentPatches/releases/latest',
		'exe' => 'UnrealTournament.exe',
	),
	'ut2004' => array(
		'iso' => array(
			'https://files.oldunreal.net/UT2004.ISO' => '2995322880_4ad34b16d757e0752809eb9bf5fb1fba',
			'https://archive.org/download/ut-2004/UT2004.ISO' => '3751510016_7841d8750e3f51aeac7bbb0448667670',
		),
		'patch' => 'https://api.github.com/repos/OldUnreal/UT2004Patches/releases/latest',
		'exe' => 'UT2004.exe',
		'deny_from_cd' => true,
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

if (isset($config['deny_from_cd'])) $from_cd = false;

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

	$iso_name = false;
	$hashes = array();
	foreach ($config['iso'] as $iso_url => $iso_data) {
		list($iso_size, $iso_hash) = explode('_', $iso_data, 2);
		$iso_size = floatval($iso_size); // Don't use intval() to avoid overflow on 32-bit PHP.
		$iso_name = basename($iso_url);
		if (file_exists($iso_name) && size_same(filesize($iso_name), $iso_size)) {
			if (!isset($hashes[$iso_name])) {
				log_('Calculate hash for '.$iso_name);
				$hashes[$iso_name] = md5_file($iso_name);
				log_('Hash: '.$hashes[$iso_name]);
			}
			if ($hashes[$iso_name] == $iso_hash) break;
		}
		$iso_name = false;
	}
	if (!$iso_name) {
		reset($config['iso']);
		$files_ou = key($config['iso']);
		if (strpos($files_ou, 'files.oldunreal.net')) {
			$hash_ou = $config['iso'][$files_ou];
			unset($config['iso'][$files_ou]);
			$servers = array();
			$servers[] = $files_ou;
			for ($i = 2; $i <= 3; $i++) {
				$servers[] = strtr($files_ou, array('files.oldunreal.net' => 'files'.$i.'.oldunreal.net'));
			}
			shuffle($servers);
			$servers = array_fill_keys($servers, $hash_ou);
			$config['iso'] = array_merge($servers, $config['iso']);
		}

		$try = 0;
		$tries = count($config['iso']);
		foreach ($config['iso'] as $iso_url => $iso_data) {
			list($iso_size, $iso_hash) = explode('_', $iso_data, 2);
			$iso_size = floatval($iso_size); // Don't use intval() to avoid overflow on 32-bit PHP.
			$try++;
			if ($iso_name && file_exists($iso_name)) unlink($iso_name);
			log_('Try obtain game ISO from '.$iso_url);
			$iso_name = basename($iso_url);

			get_file($iso_url, $iso_size, $try == $tries);

			if (!file_exists($iso_name)) {
				if ($try != $tries) continue;
				end_('Failed get game ISO from '.$iso_url);
			}

			if (size_same(filesize($iso_name), $iso_size)) {
				log_('Calculate hash for '.$iso_name);
				$file_hash = md5_file($iso_name);
				log_('Hash: '.$file_hash);
				if ($file_hash == $iso_hash) break;
			}
		}
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

$cmd_7z = 'tools\7z.exe x -aoa -o.. -bsp1 ';

if (!$cd_drive) {
	title('Unpacking game ISO...');

	if ($game == 'ut2004') {
		run('tools\7z.exe e -aoa -ocabs -bsp1 -ir!*.cab -ir!*.hdr '.escapeshellarg($iso_name));

		run('tools\unshield.exe -d data x cabs/data1.cab');

		function moveAllRecursive($src, $dst) {
			$src = rtrim($src, '\\/') ;
			$dst = rtrim($dst, '\\/') ;

			if (!is_dir($dst) && !mkdir($dst, 0777, true)) {
				log_("Failed to create destination directory: $dst");
				return;
			}

			foreach (glob($src.'/*') as $entry) {
				$base = basename($entry);
				$dstPath = $dst.DIRECTORY_SEPARATOR.$base;

				if (is_dir($entry)) {
					moveAllRecursive($entry, $dstPath);
				} elseif (is_file($entry)) {
					if (!@rename($entry, $dstPath)) {
						if (file_exists($dstPath)) {
							if (!@unlink($dstPath)) {
								log_("Cannot delete existing file: $dstPath");
							} elseif (!@rename($entry, $dstPath)) {
								log_("Failed to move file after deleting existing: $entry => $dstPath");
							}
						} else {
							log_("Failed to move file: $entry => $dstPath");
						}
					}
				}
			}
		}

		$mapping = array(
			'All_Animations' => 'Animations',
			'All_Benchmark' => 'Benchmark',
			'All_ForceFeedback' => 'ForceFeedback',
			'All_Help' => 'Help',
			'All_KarmaData' => 'KarmaData',
			'All_Maps' => 'Maps',
			'All_Music' => 'Music',
			'All_StaticMeshes' => 'StaticMeshes',
			'All_Textures' => 'Textures',
			'All_UT2004.EXE' => 'System',
			'All_Web' => 'Web',
			'English_Manual' => 'Manual',
			'English_Sounds_Speech_System_Help' => '',
			'US_License.int' => 'System',
		);
		foreach ($mapping as $from => $to) {
			if (!file_exists('data/'.$from)) continue;
			log_($from.' -> '.$to);
			moveAllRecursive('data/'.$from, '../'.$to);
		}

		run('rmdir /S /Q cabs');
		run('rmdir /S /Q data');
	} else {
		run($cmd_7z.'-x@skip.txt '.escapeshellarg($iso_name));
	}
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
if ($uzs) run('tools\uz.exe decompress "..\Maps\*.uz"');
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
	run('..\System\ucc.exe decompress '.escapeshellarg($uz));
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
	unlink($iso_name);
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
			if (size_same($filesize, $expected_size)) {
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

function size_same($filesize, $expected_size) {
	// Hack for compare file sizes bigger then 2 GB on 32-bit PHP.
	return sprintf("%u", $filesize) == sprintf("%u", $expected_size);
}

function download($url, $expected_size, $die = true) {
	$result_file = basename($url);
	log_('Start download '.$result_file.' from '.$url);

	$insecure = date('Y') < 2026 ? '--check-certificate=false ' : ''; // Wrong date -> TLS will fail (cert not yet issued) -> use insecure connection.
	if ($insecure) log_('Wrong current date on computer detected ('.date('Y-m-d').'). Use insecure connection.');
	$result = run('tools\aria2c.exe --enable-color=false --allow-overwrite=true --auto-file-renaming=false -x5 --ca-certificate=tools\ca-certificates.crt -o '.
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
	if (!size_same($filesize, $expected_size)) {
		log_('File size of '.$result_file.' is '.human_size($filesize).
			', which not match expect size '.human_size($expected_size));
		if ($filesize < 16) {
			if (!$die) return;
			end_('File size of '.$result_file.' is too small. Abort.');
		}
	}
}

function human_size($filesize) {
	return number_format(sprintf("%u", $filesize), 0, '', ' ');
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