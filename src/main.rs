use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

fn ps_exe() -> String {
    // WSL interop: powershell.exe on PATH via /mnt/c/... ; native Windows: powershell.exe
    "powershell.exe".to_string()
}

fn script_path() -> String {
    if let Ok(p) = env::var("PMCU_PS1") {
        return p;
    }
    // exe dir + ../scripts/pmcu.ps1, else cwd/scripts/pmcu.ps1, else absolute fallback
    if let Ok(exe) = env::current_exe() {
        if let Some(d) = exe.parent() {
            let c = d.join("../scripts/pmcu.ps1");
            if c.exists() {
                return c.to_string_lossy().to_string();
            }
            let c2 = d.join("scripts/pmcu.ps1");
            if c2.exists() {
                return c2.to_string_lossy().to_string();
            }
        }
    }
    let cwd = env::current_dir().unwrap_or(PathBuf::from("."));
    let c = cwd.join("scripts/pmcu.ps1");
    if c.exists() {
        return c.to_string_lossy().to_string();
    }
    "/home/user1/git/poor-mans-computer-use/scripts/pmcu.ps1".to_string()
}

fn run_ps(args: &[String]) -> (i32, String) {
    let ps1 = script_path();
    let mut cmd = Command::new(ps_exe());
    cmd.arg("-NoProfile")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-File")
        .arg(&ps1);
    for a in args {
        cmd.arg(a);
    }
    let out = cmd.output();
    match out {
        Ok(o) => {
            let mut s = String::from_utf8_lossy(&o.stdout).to_string();
            if s.is_empty() {
                s = String::from_utf8_lossy(&o.stderr).to_string();
            }
            (o.status.code().unwrap_or(1), s)
        }
        Err(e) => (127, format!("{{\"ok\":false,\"error\":{{\"code\":\"NO_INTEROP\",\"kind\":\"{}\",\"suggestion\":\"powershell.exe not reachable from WSL\"}}}}", e)),
    }
}

fn cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or("/tmp".to_string());
    PathBuf::from(home).join(".pmcu/cache")
}

fn cache_read(app: &str) -> String {
    let p = cache_dir().join(format!("{}.json", app));
    fs::read_to_string(p).unwrap_or("{\"cached\":false}".to_string())
}

fn cache_write(app: &str, body: &str) -> String {
    let d = cache_dir();
    let _ = fs::create_dir_all(&d);
    let p = d.join(format!("{}.json", app));
    let doc = format!(
        "{{\"app\":\"{}\",\"method\":\"powershell\",\"rel_xy\":{},\"saved\":true}}",
        app, body
    );
    let _ = fs::write(&p, &doc);
    doc
}

fn status_json() -> String {
    let wsl = env::var("WSL_INTEROP").unwrap_or_default();
    let wsl_distro = env::var("WSL_DISTRO_NAME").unwrap_or_default();
    let display = env::var("DISPLAY").unwrap_or_default();
    let wayland = env::var("WAYLAND_DISPLAY").unwrap_or_default();
    let ps_check = Command::new(ps_exe())
        .arg("-NoProfile")
        .arg("-Command")
        .arg("$PSVersionTable.PSVersion.ToString()")
        .output();
    let (ps_ok, ps_ver) = match ps_check {
        Ok(o) => (
            o.status.success(),
            String::from_utf8_lossy(&o.stdout).trim().to_string(),
        ),
        Err(e) => (false, e.to_string()),
    };
    let script_ok = PathBuf::from(script_path()).exists();
    format!(
        "{{\"ok\":true,\"data\":{{\"platform\":\"wsl2+windows10\",\"wsl_interop\":{},\"wsl_distro\":\"{}\",\"powershell_reachable\":{},\"powershell_version\":\"{}\",\"script_found\":{},\"displays\":{{\"DISPLAY\":\"{}\",\"WAYLAND_DISPLAY\":\"{}\"}},\"supported\":[\"window\",\"clipboard-paste\"]}}}}",
        if wsl.is_empty() { "false" } else { "true" },
        wsl_distro.replace('"', "'"),
        if ps_ok { "true" } else { "false" },
        ps_ver.replace('"', "'").replace('\n', " "),
        if script_ok { "true" } else { "false" },
        display,
        wayland
    )
}

fn usage() -> String {
    "{\"ok\":false,\"error\":{\"code\":\"INVALID_ARGS\",\"kind\":\"usage\",\"suggestion\":\"pmcu status | windows list|foreground|tile|click-at|paste|launch | cache read|write\"}}".to_string()
}

fn main() {
    let argv: Vec<String> = env::args().skip(1).collect();
    if argv.is_empty() {
        println!("{}", usage());
        return;
    }
    match argv[0].as_str() {
        "--version" | "-V" | "version" => {
            println!("pmcu {}", env!("CARGO_PKG_VERSION"))
        }
        "status" => println!("{}", status_json()),
        "windows" => {
            if argv.len() < 2 {
                println!("{}", usage());
                return;
            }
            let sub = argv[1].as_str();
            // map: windows <sub> ... -> ps1 <sub> ...
            // normalize only-filter: --only chrome stays; --app kakao -> --only KakaoTalk
            let mut ps: Vec<String> = vec![sub.to_string()];
            let mut i = 2;
            while i < argv.len() {
                if argv[i] == "--app" && i + 1 < argv.len() {
                    ps.push("--only".to_string());
                    let v = argv[i + 1].to_lowercase();
                    if v.contains("kakao") {
                        ps.push("KakaoTalk".to_string());
                    } else if v.contains("chrome") {
                        ps.push("chrome".to_string());
                    } else {
                        ps.push(argv[i + 1].clone());
                    }
                    i += 2;
                } else {
                    ps.push(argv[i].clone());
                    i += 1;
                }
            }
            // click-at default rel for kakao input area if not given
            if sub == "click-at" && !ps.iter().any(|x| x == "--rel-y") {
                // default set by ps1 (0.5, 0.9); nothing to add
            }
            let (_code, out) = run_ps(&ps);
            // cache-write on successful click-at for reuse (poor man's learning)
            if sub == "click-at" && out.contains("\"x\"") {
                // extract rel if present in args
                let mut rx = "0.5".to_string();
                let mut ry = "0.9".to_string();
                let mut only = "app".to_string();
                let mut j = 0;
                while j < ps.len() {
                    if ps[j] == "--rel-x" && j + 1 < ps.len() {
                        rx = ps[j + 1].clone();
                    }
                    if ps[j] == "--rel-y" && j + 1 < ps.len() {
                        ry = ps[j + 1].clone();
                    }
                    if ps[j] == "--only" && j + 1 < ps.len() {
                        only = ps[j + 1].clone();
                    }
                    j += 1;
                }
                let _ = cache_write(&only.to_lowercase(), &format!("[{},{}]", rx, ry));
            }
            print!("{}", out);
        }
        "cache" => {
            if argv.len() < 3 {
                println!("{}", usage());
                return;
            }
            if argv[1] == "read" {
                println!("{}", cache_read(&argv[2]));
            } else if argv[1] == "write" {
                let body = if argv.len() > 3 {
                    argv[3].clone()
                } else {
                    "[0.5,0.9]".to_string()
                };
                println!("{}", cache_write(&argv[2], &body));
            } else {
                println!("{}", usage());
            }
        }
        _ => println!("{}", usage()),
    }
}
