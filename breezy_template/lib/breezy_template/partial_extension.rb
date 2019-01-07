require 'breezy_template/breezy_template'

class BreezyTemplate
  module PartialExtension
    def set!(key, value = BLANK, *args)
      options = args.last || {}

      if args.one? && _partial_options?(options)
        _set_inline_partial key, value, options
      else
        super
      end
    end

    def array!(collection = [], *attributes)
      options = attributes.last || {}
      options = _normalize_options_for_partial(options)

      if attributes.one? && _partial_options?(options)
        _render_partial_with_collection(collection, options)
      else
        super
      end
    end

    def _extended_options?(value)
      _partial_options?(value) || super
    end

    def _partial_options?(options)
      ::Hash === options && options.key?(:partial)
    end

    def _normalize_options_for_partial(options)
      if !_partial_options?(options)
        return options
      end

      partial_options = [*options[:partial]]
      partial, rest = partial_options
      if partial && !rest
        options.dup.merge(partial: [partial, rest || {}])
      else
        options
      end
    end

    def _partial_digest(partial)
      lookup_context = @context.lookup_context
      name = lookup_context.find(partial, [], true).virtual_path
      _partial_digestor({name: name, finder: lookup_context})
    end

    def _set_inline_partial(name, object, options)
      options = _normalize_options_for_partial(options)

      partial, partial_opts = options[:partial]

      value = if object.nil? && partial.empty?
        []
      else
        locals = {}
        locals[partial_opts[:as]] = object if !_blank?(partial_opts) && partial_opts.key?(:as)
        locals.merge!(partial_opts[:locals]) if partial_opts.key? :locals
        partial_opts.merge!(locals: locals)

        _result(BLANK, options){ _render_partial(options) }
      end

      set! name, value
    end

    def _render_partial(options)
      partial, options = options[:partial]
      fragment_name = options[:fragment_name]
      if fragment_name
        fragment_name = fragment_name.to_sym
        path = @path.dup.join('.')
        @js.push "fragments['#{fragment_name}'] = fragments['#{fragment_name}'] || []; fragments['#{fragment_name}'].push('#{path}'); lastFragmentName='#{fragment_name}'; lastFragmentPath='#{path}';"
        @fragments[fragment_name]
      end

      options[:locals].merge! json: self
      @context.render options.merge(partial: partial)
    end

    def _render_partial_with_collection(collection, options)
      options = _normalize_options_for_partial(options)
      partial, partial_opts = options[:partial]
      array_opts = options.dup

      partial_opts.reverse_merge! locals: {}
      partial_opts.reverse_merge! ::BreezyTemplate.template_lookup_options
      as = partial_opts[:as]

      extract_fragment_name = partial_opts.delete(:fragment_name)
      locals = partial_opts.delete(:locals)

      array_opts.delete(:partial)
      array! collection, array_opts do |member|
        member_locals = locals.clone
        member_locals.merge! collection: collection
        member_locals.merge! as.to_sym => member if as
        partial_opts.merge!(locals: member_locals)

        if extract_fragment_name.respond_to?(:call)
          partial_opts.merge!(fragment_name: extract_fragment_name.call(member))
        end
        _render_partial options
      end
    end
  end
end
