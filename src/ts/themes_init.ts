// Copyright 2019 Istio Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

export const darkThemeClass = "dark-theme";
export const darkTheme = "Dark Theme";
export const darkThemeItem = "dark-theme-item";
export const lightTheme = "Light Theme";
export const lightThemeItem = "light-theme-item";
export const themeStorageItem = "style";

// Export should be defined at the top of the module

export let currentTheme = readLocalStorage(themeStorageItem);

export function applyStyleSheet(theme: string | null): void {
    // convert legacy cookie values
    if (theme === "dark") {
        theme = darkTheme;
    } else if (theme === "light") {
        theme = lightTheme;
    }
    theme = lightTheme;
    if (theme === darkTheme) {
        document.documentElement.classList.add(darkThemeClass);
    } else {
        document.documentElement.classList.remove(darkThemeClass);
    }

    // set the active theme menu item

    let item = document.getElementById(lightThemeItem);
    if (item) {
        if (theme === darkTheme) {
            item.classList.remove("active");
        } else {
            item.classList.add("active");
        }
    }

    item = document.getElementById(darkThemeItem);
    if (item) {
        if (theme === darkTheme) {
            item.classList.add("active");
        } else {
            item.classList.remove("active");
        }
    }
}

export function readLocalStorage(name: string): string | null {
    let value = localStorage.getItem(name);
    if (value) {
        return value;
    }

    // if couldn't find in local storage, fall back to the legacy cookies
    const nameEQ = name + "=";
    const ca = document.cookie.split(";");
    for (let c of ca) {
        while (c.charAt(0) === " ") {
            c = c.substring(1, c.length);
        }

        if (c.indexOf(nameEQ) === 0) {
            value = c.substring(nameEQ.length, c.length);

            // migrate the cookie value to localStorage
            localStorage.setItem(name, value);

            // delete the cookie once the value has been migrated to local storage
            document.cookie = name + "= ; expires = Thu, 01 Jan 1970 00:00:00 GMT";

            return value;
        }
    }

    return null;
}

function readSystemDefault(): string | null {
    if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
        return darkTheme;
    } else if (window.matchMedia("(prefers-color-scheme: light)").matches) {
        return lightTheme;
    }
    return null;
}

if (currentTheme === null) {
    currentTheme = readSystemDefault();
}
applyStyleSheet(currentTheme);
