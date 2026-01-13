# Grimoire

A module collection for [Hjem](https://github.com/feel-co/hjem)

## What is it exactly?

This is a collection of Nix modules for various programs and services similar to Home Manager but extends Hjem.

## Rationale

I'd first like to acknowledge [Hjem Rum](https://github.com/snugnug/hjem-rum) as inspiration for this particular collection. Similar to what they're doing I wanted to create my own spin to it since I can go ahead and iterate on my own modules on my own time and learn my system better as I grow a wider collection of these programs. I actually got some pretty good learning off of doing this. I'm pretty new to Nix and Linux for daily driving.

Initially I wasn't going to release this but someone on X [asked](https://x.com/shtts_s/status/2010559847729934579?s=20) if there was a repo link after posting about it. Decided to say screw it and release it. Maybe I can get some valuable roasting for the code I've written. It'll only drive me to better use Nix, the language and the distro, in the long run.

## Setup

You should keep in mind that this project depends on Hjem. If something breaks then there was probably something that changed in Hjem's tooling.

To start using Grimoire you need to have hjem installed and you need update your flake.nix by adding the following snippet to your inputs:

```nix
inputs = {
	...
	grimoire = {
		url = "github:critical/grimoire";
		inputs.nixpkgs.follows = "nixpkgs";
		inputs.hjem.follows = "hjem";
	};
}
```

Next you want to add the grimoire `hjemModules` into the `extraModules` attribute in Hjem's settings:

```nix
	hjem = {
		extraModules = [
			inputs.grimoire.hjemModules.default
		];
		...
	}
```

Then you can modify options in any module that exists within grimoire like this example:

```nix
	hjem.users.<username> = {
		grimoire = {
			desktops.hyprland = { ... };
			programs = {
				ssh = {
					enable = true;
					blocks = [
						{
							host = "*";
						    	options.IdentityAgent = "~/.1password/agent.sock";
						}
					];
				};
			};
			services = { ... };
		};
	};
```
