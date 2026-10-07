FROM debian:stable-slim

RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    bash ca-certificates curl emacs-nox fish git procps tar xz-utils wget

RUN useradd --create-home --shell /usr/bin/fish dev

USER dev
ENV PATH="/home/dev/.local/bin:${PATH}"

# Same links as on the host; ~/.dotfiles is bind-mounted (see devcontainer.json).
RUN mkdir -p ~/.config/fish ~/.emacs.d \
    && ln -s ~/.dotfiles/share/config/fish/config.fish ~/.config/fish/ \
    && for f in early-init.el hooks init.el keys.el site-lisp; do ln -s ~/.dotfiles/share/emacs.d/$f ~/.emacs.d/; done

# Exists in the image so the named volume mounted here inherits dev ownership.
RUN mkdir /home/dev/.claude

RUN curl -fsSL https://claude.ai/install.sh | bash
