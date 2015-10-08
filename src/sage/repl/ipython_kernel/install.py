"""
Installing the SageMath Jupyter Kernel

Kernels have to register themselves with Jupyter so that they appear
in the Jupyter notebook's kernel drop-down. This is done by
:class:`SageKernelSpec`.
"""

import os
import errno

from IPython.paths import get_ipython_dir

from sage.env import (
    SAGE_ROOT, SAGE_DOC, SAGE_LOCAL, SAGE_EXTCODE,
    SAGE_VERSION
)
from jupyter_core.paths import ENV_JUPYTER_PATH


class SageKernelSpec(object):

    def __init__(self):
        """
        Utility to manage SageMath kernels

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: spec = SageKernelSpec()
            sage: spec._display_name    # random output
            'SageMath 6.9'
        """
        self._display_name = 'SageMath {0}'.format(SAGE_VERSION)
        self._ipython_dir = get_ipython_dir()
        self.kernel_dir = os.path.join(ENV_JUPYTER_PATH[0], "kernels", self.identifier())
        self._mkdirs()

    def _mkdirs(self):
        """
        Create necessary parent directories

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: spec = SageKernelSpec()
            sage: spec._mkdirs()
            sage: nbextensions = os.path.join(spec._ipython_dir, 'nbextensions')
            sage: os.path.isdir(nbextensions)
            True
        """
        def mkdir_p(*path_components):
            path = os.path.join(*path_components)
            try:
                os.makedirs(path)
            except OSError:
                if not os.path.isdir(path):
                    raise
        mkdir_p(self._ipython_dir, 'nbextensions')
        mkdir_p(self.kernel_dir)

    @classmethod
    def identifier(cls):
        """
        Internal identifier for the SageMath kernel

        OUTPUT: the string ``"sagemath"``.

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: SageKernelSpec.identifier()
            'sagemath'
        """
        return 'sagemath'

    def symlink(self, src, dst):
        """
        Symlink ``src`` to ``dst``

        This is not an atomic operation.

        Already-existing symlinks will be deleted, already existing
        non-empty directories will be kept.

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: spec = SageKernelSpec()
            sage: path = tmp_dir()
            sage: spec.symlink(os.path.join(path, 'a'), os.path.join(path, 'b'))
            sage: os.listdir(path)
            ['b']
        """
        try:
            os.remove(dst)
        except OSError as err:
            if err.errno == errno.EEXIST:
                return
        os.symlink(src, dst)

    def use_local_mathjax(self):
        """
        Symlink SageMath's Mathjax install to the Jupyter notebook.

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: from IPython.paths import get_ipython_dir
            sage: spec = SageKernelSpec()
            sage: spec.use_local_mathjax()
            sage: ipython_dir = get_ipython_dir()
            sage: mathjax = os.path.join(ipython_dir, 'nbextensions', 'mathjax')
            sage: os.path.exists(mathjax)
            True
        """
        src = os.path.join(SAGE_LOCAL, 'share', 'mathjax')
        dst = os.path.join(self._ipython_dir, 'nbextensions', 'mathjax')
        self.symlink(src, dst)

    def use_local_jsmol(self):
        src = os.path.join(SAGE_LOCAL, 'share', 'jsmol')
        dst = os.path.join(self._ipython_dir, 'nbextensions', 'jsmol')
        self.symlink(src, dst)

    def _kernel_cmd(self):
        """
        Helper to construct the SageMath kernel command.

        OUTPUT:

        List of strings. The command to start a new SageMath kernel.

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: spec = SageKernelSpec()
            sage: spec._kernel_cmd()
            ['/.../sage',
             '--python',
             '-m',
             'sage.repl.ipython_kernel',
             '-f',
             '{connection_file}']
        """
        return [
            os.path.join(SAGE_ROOT, 'sage'),
            '--python',
            '-m', 'sage.repl.ipython_kernel',
            '-f', '{connection_file}',
        ]

    def kernel_spec(self):
        """
        Return the kernel spec as Python dictionary

        OUTPUT:

        A dictionary. See the Jupyter documentation for details.

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: spec = SageKernelSpec()
            sage: spec.kernel_spec()
            {'argv': ..., 'display_name': 'SageMath ...'}
        """
        return dict(
            argv=self._kernel_cmd(),
            display_name=self._display_name,
        )

    def _install_spec(self):
        """
        Install the SageMath Jupyter kernel

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: spec = SageKernelSpec()
            sage: spec._install_spec()    # not tested
        """
        jsonfile = os.path.join(self.kernel_dir, "kernel.json")
        import json
        with open(jsonfile, 'w') as f:
            json.dump(self.kernel_spec(), f)

    def _symlink_resources(self):
        """
        Symlink miscellaneous resources

        This method symlinks additional resources (like the SageMath
        documentation) into the SageMath kernel directory. This is
        necessary to make the help links in the notebook work.

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: spec = SageKernelSpec()
            sage: spec._install_spec()         # not tested
            sage: spec._symlink_resources()    # not tested
        """
        path = os.path.join(SAGE_EXTCODE, 'notebook-ipython')
        for filename in os.listdir(path):
            self.symlink(
                os.path.join(path, filename),
                os.path.join(self.kernel_dir, filename)
            )
        self.symlink(
            os.path.join(SAGE_DOC, 'output', 'html', 'en'),
            os.path.join(self.kernel_dir, 'doc')
        )

    @classmethod
    def update(cls):
        """
        Configure the Jupyter notebook for the SageMath kernel

        This method does everything necessary to use the SageMath kernel,
        you should never need to call any of the other methods
        directly.

        EXAMPLES::

            sage: from sage.repl.ipython_kernel.install import SageKernelSpec
            sage: spec = SageKernelSpec()
            sage: spec.update()  # not tested
        """
        instance = cls()
        instance.use_local_mathjax()
        instance.use_local_jsmol()
        instance._install_spec()
        instance._symlink_resources()


def have_prerequisites():
    """
    Check that we have all prerequisites to run the Jupyter notebook.

    In particular, the Jupyter notebook requires OpenSSL whether or
    not you are using https. See :trac:`17318`.

    OUTPUT:

    Boolean.

    EXAMPLES::

        sage: from sage.repl.ipython_kernel.install import have_prerequisites
        sage: have_prerequisites() in [True, False]
        True
    """
    try:
        from notebook.notebookapp import NotebookApp
        return True
    except ImportError:
        return False
