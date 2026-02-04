/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `add-preset-1` command */
  export type AddPreset1 = ExtensionPreferences & {}
  /** Preferences accessible in the `add-preset-2` command */
  export type AddPreset2 = ExtensionPreferences & {}
  /** Preferences accessible in the `add-preset-3` command */
  export type AddPreset3 = ExtensionPreferences & {}
  /** Preferences accessible in the `add-water` command */
  export type AddWater = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `add-preset-1` command */
  export type AddPreset1 = {}
  /** Arguments passed to the `add-preset-2` command */
  export type AddPreset2 = {}
  /** Arguments passed to the `add-preset-3` command */
  export type AddPreset3 = {}
  /** Arguments passed to the `add-water` command */
  export type AddWater = {
  /** e.g. 250 */
  "ml": string
}
}

